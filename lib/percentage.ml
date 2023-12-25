let group_by f l =
  let rec grouping acc = function
    | [] -> acc
    | hd :: tl ->
      let l1, l2 = List.partition (fun x -> f hd == f x) tl in
      grouping ((f hd, hd :: l1) :: acc) l2
  in
  grouping [] l
;;

let group_by_project =
  group_by (fun time_entry -> Timesheet.entry_project time_entry)
;;

module SM = Map.Make (String)
module IM = Map.Make (Int)

let time_entries_by_project time_entries (projects : Project.t IM.t) =
  List.fold_left
    (fun m time_entry ->
      let label =
        match Timesheet.entry_project time_entry with
        | None -> "unknown"
        | Some project_id ->
          (match IM.find_opt project_id projects with
           | None -> "unknown"
           | Some { name; _ } -> name)
      in
      SM.update
        label
        (function
          | None -> Some [ time_entry ]
          | Some time_entries -> Some (time_entry :: time_entries))
        m)
    SM.empty
    time_entries
;;

module P = Project

let projects_map =
  List.fold_left (fun m p -> IM.add (Project.id p) p m) IM.empty
;;

let project_durations time_entries projects_map =
  let label entry =
    match Timesheet.entry_project entry with
    | None -> "unknown"
    | Some project_id ->
      (match IM.find_opt project_id projects_map with
       | None -> "unknown"
       | Some p -> P.name p)
  in
  List.fold_left
    (fun m t ->
      SM.update
        (label t)
        (function
          | None -> Some (Timesheet.entry_duration t)
          | Some f -> Some (f +. Timesheet.entry_duration t))
        m)
    SM.empty
    time_entries
;;

let render_result sm =
  print_endline "\"Project\",\"Percentage (exact)\",\"Percentage (rounded)\"";
  SM.iter
    (fun project_name (overall_hours, percentage, percentage_rounded) ->
      Printf.printf
        "%s,%ih,%f%%,%i%%\n"
        project_name
        overall_hours
        percentage
        percentage_rounded)
    sm;
  let percentages =
    SM.bindings sm
    |> List.map (fun (_, (_, x, _)) -> x)
    |> List.fold_left ( +. ) 0.
  in
  let percentages_rounded =
    SM.bindings sm
    |> List.map (fun (_, (_, _, x)) -> x)
    |> List.fold_left ( + ) 0
  in
  Printf.printf
    "control exact: %f%%, control rounded: %i%%"
    percentages
    percentages_rounded
;;

let run request_cfg =
  let ( let* ) = Api.bind in
  let* projects = Api.run_request request_cfg P.api_get in
  let* timesheet = Api.run_request request_cfg Timesheet.get_timesheet in
  let durations = project_durations timesheet (projects_map projects) in
  let overall_duration =
    SM.bindings durations |> List.fold_left (fun acc kv -> acc +. snd kv) 0.0
  in
  let int_floor f = Float.round f |> int_of_float in
  durations
  |> SM.map (fun duration ->
    let percentage = duration /. overall_duration *. 100. in
    int_floor duration, percentage, int_floor percentage)
  |> Lwt.return_ok
;;
