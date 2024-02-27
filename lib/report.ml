module Timesheet = struct
  let projects_matches project_ids =
    if [] == project_ids
    then fun _ -> true
    else
      fun entry ->
      let project = Entry.project entry in
      match project with
      | None -> false
      | Some project_id -> List.mem project_id project_ids
  ;;

  let fill_description activity_by_id entry =
    let description =
      match Entry.description entry, Entry.activity entry with
      | Some description, Some _ -> Some description
      | Some description, None -> Some description
      | None, Some activity_id ->
        activity_by_id activity_id |> Option.map Activity.name
      | None, None -> None
    in
    Entry.with_description entry description
  ;;

  let exec ?(project_names = []) (module R : Repo.S) begin_date end_date =
    let ( let* ) = Api.bind in
    let* projects = R.find_projects () in
    let* activities = R.find_activities () in
    let module RU = Repo.Repo_utils (R) (Repo.Bi_lookup.Hash) in
    let id_by_name = RU.id_by_name (module Project) projects in
    let some_project_ids, none_project_names =
      List.fold_left
        (fun (some_project_ids, none_project_names) project_name ->
          match id_by_name project_name with
          | Some id -> id :: some_project_ids, none_project_names
          | None -> some_project_ids, project_name :: none_project_names)
        ([], [])
        project_names
    in
    if [] == none_project_names
    then
      let* timesheet = R.find_timesheet begin_date end_date in
      timesheet
      |> List.filter (projects_matches some_project_ids)
      |> List.map (fill_description @@ RU.by_id (module Activity) activities)
      |> List.rev
      |> Lwt.return_ok
    else
      Lwt.return_error
      @@ Printf.sprintf
           "projects [ %s ] do not exist"
           (String.concat ", " none_project_names)
  ;;

  let print_csv emit_column_headers =
    if emit_column_headers
    then Printf.printf "\"Date\",\"Duration\",\"Description\"\n";
    List.iter (fun entry ->
      Printf.printf
        "%s,%f,\"%s\"\n"
        (Entry.date_string entry)
        (Entry.duration entry)
        (Option.value (Entry.description entry) ~default:"no description"))
  ;;

  let overall_duration timesheet =
    List.fold_left (fun acc entry -> acc +. Entry.duration entry) 0. timesheet
  ;;

  let print_overall_duration timesheet =
    timesheet |> overall_duration |> Printf.printf "Overall hours:\n%f"
  ;;
end

module Percentage = struct
  module SM = Map.Make (String)

  let project_durations time_entries project_by_id =
    let label entry =
      match Entry.project entry with
      | None -> "unknown"
      | Some project_id ->
        (match project_by_id project_id with
         | None -> "unknown"
         | Some p -> Project.name p)
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
    let module RU = Repo.Repo_utils (R) (Repo.Bi_lookup.Hash) in
    let project_by_id = RU.by_id (module Project) projects in
    let durations = project_durations timesheet project_by_id in
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
