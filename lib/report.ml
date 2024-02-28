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

  let fill_description
    ?(prepend_project_name = false)
    activity_by_id
    project_by_id
    entry
    =
    let description_opt =
      match Entry.description entry, Entry.activity entry with
      | Some description, Some _ -> Some description
      | Some description, None -> Some description
      | None, Some activity_id -> activity_by_id activity_id
      | None, None -> None
    in
    let description_with_project_opt =
      if prepend_project_name
      then (
        let project_name_opt =
          match Entry.project entry with
          | Some project_id -> project_by_id project_id
          | None -> None
        in
        match project_name_opt, description_opt with
        | Some project_name, Some description ->
          Some (Printf.sprintf "%s: %s" project_name description)
        | None, description_opt -> description_opt
        | project_name_opt, None -> project_name_opt)
      else description_opt
    in
    Entry.with_description entry description_with_project_opt
  ;;

  let exec
    ?(project_names = [])
    ?(prepend_project_name = false)
    (module R : Repo.S)
    begin_date
    end_date
    =
    let ( let* ) = Api.bind in
    let* projects = R.find_projects () in
    let* activities = R.find_activities () in
    let module RU = Repo.Repo_utils (R) (Repo.Bi_lookup.Map) in
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
      |> List.map
           (fill_description
              ~prepend_project_name
              (RU.name_by_id (module Activity) activities)
              (RU.name_by_id (module Project) projects))
      |> List.rev
      |> Lwt.return_ok
    else
      Lwt.return_error
      @@ Printf.sprintf
           "Projects do not exist: [%s]"
           (String.concat ", " none_project_names)
  ;;

  let print_csv emit_column_headers =
    if emit_column_headers
    then Printf.printf "\"Date\",\"Duration\",\"Description\"\n";
    List.iter (fun entry ->
      Printf.printf
        "\"%s\",\"%.2f\",\"%s\"\n"
        (Entry.date_string entry)
        (Entry.duration entry)
        (Option.value (Entry.description entry) ~default:"no description"))
  ;;

  let overall_duration timesheet =
    List.fold_left (fun acc entry -> acc +. Entry.duration entry) 0. timesheet
  ;;

  let print_overall_duration timesheet =
    timesheet |> overall_duration |> Printf.eprintf "Overall hours:\n%.2f"
  ;;
end

module Percentage = struct
  module SM = Map.Make (String)

  let project_labels (module R : Repo.S) projects =
    let module RU = Repo.Repo_utils (R) (Repo.Bi_lookup.Map) in
    let project_by_id = RU.by_id (module Project) projects in
    let label entry =
      match Entry.project entry with
      | None -> "unknown"
      | Some project_id ->
        (match project_by_id project_id with
         | None -> "unknown"
         | Some p -> Project.name p)
    in
    label
  ;;

  let customer_labels (module R : Repo.S) projects customers =
    let module RU = Repo.Repo_utils (R) (Repo.Bi_lookup.Map) in
    let project_by_id = RU.by_id (module Project) projects in
    let customer_by_id = RU.by_id (module Customer) customers in
    let label entry =
      match Entry.project entry with
      | None -> "unknown"
      | Some project_id ->
        (match project_by_id project_id with
         | None -> "unknown"
         | Some p ->
           (match customer_by_id @@ Project.customer p with
            | None -> "unknown"
            | Some c -> Customer.name c))
    in
    label
  ;;

  let durations_by_label time_entries by_label =
    List.fold_left
      (fun m t ->
        SM.update
          (by_label t)
          (function
            | None -> Some (Entry.duration t)
            | Some f -> Some (f +. Entry.duration t))
          m)
      SM.empty
      time_entries
  ;;

  let exec ?(by_customers = false) (module R : Repo.S) begin_date end_date =
    let ( let* ) = Api.bind in
    let* projects = R.find_projects () in
    let* customers = R.find_customers () in
    let* timesheet = R.find_timesheet begin_date end_date in
    let durations =
      durations_by_label
        timesheet
        (if by_customers
         then customer_labels (module R) projects customers
         else project_labels (module R) projects)
    in
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
          "%s,%ih,%.2f%%,%i%%\n"
          project_name
          overall_hours
          percentage
          percentage_rounded)
      entries
  ;;
end
