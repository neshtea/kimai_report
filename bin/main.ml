module C = Cmdliner
module K = Kimai_report

let server api_url api_user api_pwd port =
  let module RC = (val K.Api.make_request_cfg api_url api_user api_pwd) in
  let module R = K.Repo.Cohttp (RC) in
  K.Web.start_server (module R : K.Repo.S) port
;;

let timesheet
  api_url
  api_user
  api_pwd
  begin_date
  end_date
  project_names
  show_overall_duration
  emit_column_headers
  prepend_project_name
  =
  let module RC = (val K.Api.make_request_cfg api_url api_user api_pwd) in
  let module R = K.Repo.Cohttp (RC) in
  match
    K.Report.Timesheet.exec
      ~project_names
      ~prepend_project_name
      (module R)
      begin_date
      end_date
    |> Lwt_main.run
  with
  | Error err -> prerr_endline @@ "Error: " ^ err
  | Ok timesheet ->
    let () = K.Report.Timesheet.print_csv emit_column_headers timesheet in
    if show_overall_duration
    then K.Report.Timesheet.print_overall_duration timesheet
    else ()
;;

let percentage api_url api_user api_pwd begin_date end_date by_customers =
  let module RC = (val K.Api.make_request_cfg api_url api_user api_pwd) in
  let module R = K.Repo.Cohttp (RC) in
  match
    K.Report.Percentage.exec ~by_customers (module R) begin_date end_date
    |> Lwt_main.run
  with
  | Error err -> prerr_endline @@ "Error: " ^ err
  | Ok percentages -> K.Report.Percentage.print_csv percentages
;;

let working_time
  api_url
  api_user
  api_pwd
  begin_date
  end_date
  emit_column_headers
  project_names
  =
  let module RC = (val K.Api.make_request_cfg api_url api_user api_pwd) in
  let module R = K.Repo.Cohttp (RC) in
  match
    K.Report.Working_time.exec ~project_names (module R) begin_date end_date
    |> Lwt_main.run
  with
  | Error err -> prerr_endline @@ "Error: " ^ err
  | Ok timesheet ->
    let () = K.Report.Working_time.print_csv emit_column_headers timesheet in
    ()
;;

let record
  api_url
  api_user
  api_pwd
  begin_date_time
  end_date_time
  project_name
  activity_name
  description
  =
  let module RC = (val K.Api.make_request_cfg api_url api_user api_pwd) in
  let module R = K.Repo.Cohttp (RC) in
  match
    K.Record.Record.exec
      (module R)
      begin_date_time
      end_date_time
      project_name
      activity_name
      description
    |> Lwt_main.run
  with
  | Error err -> prerr_endline @@ "Error: " ^ err
  | Ok _result -> ()
;;

let api_url =
  let doc = "The base url of the API endpoint you want to talk to." in
  C.Arg.(value @@ pos 0 string "" @@ info [] ~docv:"API_URL" ~doc)
;;

let api_user =
  let doc = "The user connecting to the API." in
  C.Arg.(value @@ pos 1 string "" @@ info [] ~docv:"API_USER" ~doc)
;;

let api_pwd =
  let doc = "The password of the user connecting to the of the API to." in
  C.Arg.(value @@ pos 2 string "" @@ info [] ~docv:"API_PWD" ~doc)
;;

let project_names =
  let doc =
    "Name of the project the timesheet is generated for. If not given, exports \
     all projects. If given more than once, exports all the given projects."
  in
  C.Arg.(value @@ opt_all string [] @@ info [ "project" ] ~doc)
;;

let show_overall_duration =
  let doc =
    "Whether or not to print the overall duration of the generated timesheet."
  in
  C.Arg.(value @@ flag @@ info [ "show_duration" ] ~doc)
;;

let emit_column_headers =
  let doc = "Whether or not to emit the headers of the generated timesheet." in
  C.Arg.(value @@ flag @@ info [ "emit_column_headers" ] ~doc)
;;

let prepend_project_name =
  let doc =
    "Whether or not to prepend the project name to the descriptions of the \
     entries. This is useful if a timesheet covers different projects at once."
  in
  C.Arg.(value @@ flag @@ info [ "prepend_project_name" ] ~doc)
;;

let date =
  let parse s =
    try K.Date.from_string_exn s |> Result.ok with
    | K.Date.Date_format_error s ->
      Error (`Msg (Printf.sprintf "%s is not a valid date" s))
  in
  let print ppf s =
    Format.fprintf ppf "%s" (Printf.sprintf "+%s" (K.Date.to_html5_string s))
  in
  C.Arg.conv ~docv:"FROM" (parse, print)
;;

let begin_date =
  let doc =
    "The earliest date to consider when generating the report. Format is \
     YYYY-mm-DD. Defaults to the first of the current month."
  in
  C.Arg.(value @@ opt date (K.Date.start_of_month ()) @@ info [ "begin" ] ~doc)
;;

let end_date =
  let doc =
    "The latest date to consider when generating the report. Format is \
     YYYY-mm-DD. Default to todays date."
  in
  C.Arg.(value @@ opt date (K.Date.today ()) @@ info [ "end" ] ~doc)
;;

let percentage_by_customers =
  let doc =
    "Whether to calculate percentages per customers or per projects. Default \
     is per projects."
  in
  C.Arg.(value @@ flag @@ info [ "by_customers" ] ~doc)
;;

let timesheet_t =
  C.Term.(
    const timesheet
    $ api_url
    $ api_user
    $ api_pwd
    $ begin_date
    $ end_date
    $ project_names
    $ show_overall_duration
    $ emit_column_headers
    $ prepend_project_name)
;;

let timesheet_cmd =
  let doc = "Generate a timesheet." in
  let info = C.Cmd.info "timesheet" ~doc in
  C.Cmd.v info timesheet_t
;;

let percentage_t =
  C.Term.(
    const percentage
    $ api_url
    $ api_user
    $ api_pwd
    $ begin_date
    $ end_date
    $ percentage_by_customers)
;;

let percentage_cmd =
  let doc = "Generate the percentages of projects to logged time." in
  let info = C.Cmd.info "percentage" ~doc in
  C.Cmd.v info percentage_t
;;

let working_time_project_names =
  let doc =
    "Name of the projects that are not included in the working-times report. \
     If not given, all projects are included. If given more than once, does \
     not include all the given projects."
  in
  C.Arg.(value @@ opt_all string [] @@ info [ "project" ] ~doc)
;;

let working_time_t =
  C.Term.(
    const working_time
    $ api_url
    $ api_user
    $ api_pwd
    $ begin_date
    $ end_date
    $ emit_column_headers
    $ working_time_project_names)
;;

let working_time_cmd =
  let doc = "Generate a working-time sheet." in
  let info = C.Cmd.info "working_time" ~doc in
  C.Cmd.v info working_time_t
;;

let port =
  let doc = "The port on which the webserver should listen" in
  C.Arg.(value @@ opt int 8080 @@ info [ "port" ] ~doc)
;;

let server_t = C.Term.(const server $ api_url $ api_user $ api_pwd $ port)

let server_cmd =
  let doc = "A small webclient for fetching and displaying reports." in
  let info = C.Cmd.info "server" ~doc in
  C.Cmd.v info server_t
;;

let record_begin_date_time =
  let doc =
    "The begin date and time of the entry. Format is `YYYY-mm-DD HH:MM:SS`."
  in
  C.Arg.(required @@ opt (some string) None @@ info [ "begin" ] ~doc)
;;

let record_end_date_time =
  let doc =
    "The end date and time of the entry. Format is `YYYY-mm-DD HH:MM:SS`."
  in
  C.Arg.(required @@ opt (some string) None @@ info [ "end" ] ~doc)
;;

let record_project_name =
  let doc = "Name of the project the entry is recorded to." in
  C.Arg.(required @@ opt (some string) None @@ info [ "project" ] ~doc)
;;

let record_activity_name =
  let doc = "Name of the activity of the entry." in
  C.Arg.(required @@ opt (some string) None @@ info [ "activity" ] ~doc)
;;

let record_description =
  let doc = "Description of the entry." in
  C.Arg.(required @@ opt (some string) None @@ info [ "description" ] ~doc)
;;

let record_t =
  C.Term.(
    const record
    $ api_url
    $ api_user
    $ api_pwd
    $ record_begin_date_time
    $ record_end_date_time
    $ record_project_name
    $ record_activity_name
    $ record_description)
;;

let record_cmd =
  let doc = "Record a timesheet entry." in
  let info = C.Cmd.info "record" ~doc in
  C.Cmd.v info record_t
;;

let main_cmd =
  let doc =
    "Interact with a Kimai instance for generating reports and recording \
     timesheet entries."
  in
  let info = C.Cmd.info "kimai_report" ~doc in
  C.Cmd.group
    info
    [ timesheet_cmd; percentage_cmd; working_time_cmd; server_cmd; record_cmd ]
;;

let main () = exit (C.Cmd.eval main_cmd)
let () = main ()
