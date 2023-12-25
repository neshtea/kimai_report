module C = Cmdliner

let timesheet api_url api_user api_pwd project_name =
  match
    Lwt_main.run
    @@ Kimai_report.Timesheet.run ?project_name
    @@ Kimai_report.Api.make_request_cfg api_url api_user api_pwd
  with
  | Error err ->
    print_endline @@ "Error:" ^ Kimai_report.Decoder.Yojson.Safe.Error.show err
  | Ok timesheet -> Kimai_report.Timesheet.render_timesheet timesheet
;;

let percentage api_url api_user api_pwd =
  match
    Lwt_main.run
    @@ Kimai_report.Percentage.run
    @@ Kimai_report.Api.make_request_cfg api_url api_user api_pwd
  with
  | Error err ->
    print_endline @@ "Error:" ^ Kimai_report.Decoder.Yojson.Safe.Error.show err
  | Ok percentages -> Kimai_report.Percentage.render_result percentages
;;

let api_url =
  let doc = "The base url of the API endpoint you want to talk to." in
  C.Arg.(value @@ opt string "" @@ info [ "api_url" ] ~doc)
;;

let api_user =
  let doc = "The user connecting to the API." in
  C.Arg.(value @@ opt string "" @@ info [ "api_user" ] ~doc)
;;

let api_pwd =
  let doc = "The password of the user connecting to the of the API to." in
  C.Arg.(value @@ opt string "" @@ info [ "api_pwd" ] ~doc)
;;

let project_name =
  let doc =
    "Name of the project the timesheet is generated for. If not given, exports \
     all projects."
  in
  C.Arg.(value @@ opt (some string) None @@ info [ "project" ] ~doc)
;;

let timesheet_t =
  C.Term.(const timesheet $ api_url $ api_user $ api_pwd $ project_name)
;;

let timesheet_cmd =
  let info = C.Cmd.info "timesheet" in
  C.Cmd.v info timesheet_t
;;

let percentage_t = C.Term.(const percentage $ api_url $ api_user $ api_pwd)

let percentage_cmd =
  let info = C.Cmd.info "percentage" in
  C.Cmd.v info percentage_t
;;

let main_cmd =
  let doc =
    "generate controlling information for internal controlling from a kimai \
     instance"
  in
  let info = C.Cmd.info "kimai_report" ~doc in
  let default = timesheet_t in
  C.Cmd.group info ~default [ timesheet_cmd; percentage_cmd ]
;;

let main () = exit (C.Cmd.eval main_cmd)
let () = main ()
