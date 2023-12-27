module Timesheet = struct
  module IM = Map.Make (Int)
  module SM = Map.Make (String)
  module A = Activity
  module P = Project

  let projects_map =
    List.fold_left (fun m p -> SM.add (P.name p) (P.id p) m) SM.empty
  ;;

  let activities_map =
    List.fold_left (fun m a -> IM.add (A.id a) (A.name a) m) IM.empty
  ;;

  let project_matches project_name projects_map =
    match project_name with
    | None -> fun _ -> true
    | Some project_name ->
      fun entry ->
        let project = Entry.project entry in
        (match project with
         | None -> false
         | Some project_id ->
           (match SM.find_opt project_name projects_map with
            | None -> false
            | Some pid -> pid == project_id))
  ;;

  let fill_description activities_map entry =
    let description =
      match Entry.description entry, Entry.activity entry with
      | Some description, Some _ -> Some description
      | Some description, None -> Some description
      | None, Some activity_id -> IM.find_opt activity_id activities_map
      | None, None -> None
    in
    Entry.with_description entry description
  ;;

  let exec ?(project_name = None) (module R : Repo.S) begin_date end_date =
    let ( let* ) = Api.bind in
    let* projects = R.find_projects () in
    let* activities = R.find_activities () in
    let* timesheet = R.find_timesheet begin_date end_date in
    timesheet
    |> List.filter (project_matches project_name @@ projects_map projects)
    |> List.map (fill_description @@ activities_map activities)
    |> List.rev
    |> Lwt.return_ok
  ;;

  let print_csv =
    List.iter (fun entry ->
      Printf.printf
        "%s,%f,\"%s\"\n"
        (Entry.date_string entry)
        (Entry.duration entry)
        (Option.value (Entry.description entry) ~default:"no description"))
  ;;
end

module Percentage = struct
  module SM = Map.Make (String)
  module IM = Map.Make (Int)
  module P = Project

  let projects_map =
    List.fold_left (fun m p -> IM.add (Project.id p) p m) IM.empty
  ;;

  let project_durations time_entries projects_map =
    let label entry =
      match Entry.project entry with
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
            | None -> Some (Entry.duration t)
            | Some f -> Some (f +. Entry.duration t))
          m)
      SM.empty
      time_entries
  ;;

  let exec (module R : Repo.S) begin_date end_date =
    let ( let* ) = Api.bind in
    let* projects = R.find_projects () in
    let* timesheet = R.find_timesheet begin_date end_date in
    let durations = project_durations timesheet (projects_map projects) in
    let overall_duration =
      SM.bindings durations |> List.fold_left (fun acc kv -> acc +. snd kv) 0.0
    in
    let int_floor f = Float.round f |> int_of_float in
    durations
    |> SM.map (fun duration ->
      let percentage = duration /. overall_duration *. 100. in
      int_floor duration, percentage, int_floor percentage)
    |> SM.bindings
    |> Lwt.return_ok
  ;;

  let print_csv entries =
    List.iter
      (fun (project_name, (overall_hours, percentage, percentage_rounded)) ->
        Printf.printf
          "%s,%ih,%f%%,%i%%\n"
          project_name
          overall_hours
          percentage
          percentage_rounded)
      entries
  ;;
end
