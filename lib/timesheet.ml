type entry =
  { date : Ptime.t
  ; duration : float
  ; activity : int option
  ; description : string option
  ; project : int option
  }

let entry_project { project; _ } = project
let entry_duration { duration; _ } = duration

type timesheet = entry list

let split_timestamp s =
  match Str.split (Str.regexp "T") s with
  | [] -> ""
  | x :: _ -> x
;;

let render_timesheet =
  List.iter (fun { date; duration; description; _ } ->
    Printf.printf
      "%s,%f,\"%s\"\n"
      (Ptime.to_rfc3339 date |> split_timestamp)
      duration
      (Option.value description ~default:"no description"))
;;

module D = Decoder.Yojson.Safe

let timesheet_decoder =
  let open D.Syntax in
  let entry_decoder =
    let* date = D.field "begin" Api.timestamp_decoder in
    let* description = D.optional @@ D.field "description" D.string in
    let* activity = D.optional @@ D.field "activity" D.int in
    let* duration' = D.field "duration" D.int in
    let duration = float_of_int duration' /. 60. /. 60. in
    let* project = D.optional @@ D.field "project" D.int in
    D.return { date; duration; activity; description; project }
  in
  D.list entry_decoder
;;

module IM = Map.Make (Int)
module SM = Map.Make (String)
module A = Activity
module P = Project

let get_timesheet = Api.make_api_get_request "/timesheets" timesheet_decoder

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
    fun { project; _ } ->
      (match project with
       | None -> false
       | Some project_id ->
         (match SM.find_opt project_name projects_map with
          | None -> false
          | Some pid -> pid == project_id))
;;

let fill_description activities_map entry =
  let description =
    match entry.description, entry.activity with
    | Some description, Some _ -> Some description
    | Some description, None -> Some description
    | None, Some activity_id -> IM.find_opt activity_id activities_map
    | None, None -> None
  in
  { entry with description }
;;

let run ?project_name request_cfg =
  let ( let* ) = Api.bind in
  let* projects = Api.run_request request_cfg P.api_get in
  let* activities = Api.run_request request_cfg A.api_get in
  let* timesheet = Api.run_request request_cfg get_timesheet in
  timesheet
  |> List.filter (project_matches project_name @@ projects_map projects)
  |> List.map (fill_description @@ activities_map activities)
  |> List.rev
  |> Lwt.return_ok
;;
