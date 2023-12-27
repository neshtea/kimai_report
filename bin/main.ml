module C = Cmdliner
module K = Kimai_report

let timesheet api_url api_user api_pwd begin_date end_date project_name =
  let module RC = (val K.Api.make_request_cfg_m api_url api_user api_pwd) in
  let module R = K.Repo.Cohttp (RC) in
  match
    K.Report.Timesheet.exec ~project_name (module R) begin_date end_date
    |> Lwt_main.run
  with
  | Error err -> print_endline @@ "Error:" ^ err
  | Ok timesheet -> K.Report.Timesheet.print_csv timesheet
;;

let percentage api_url api_user api_pwd begin_date end_date =
  let module RC = (val K.Api.make_request_cfg_m api_url api_user api_pwd) in
  let module R = K.Repo.Cohttp (RC) in
  match
    K.Report.Percentage.exec (module R) begin_date end_date |> Lwt_main.run
  with
  | Error err -> print_endline @@ "Error:" ^ err
  | Ok percentages -> K.Report.Percentage.print_csv percentages
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

let project_name =
  let doc =
    "Name of the project the timesheet is generated for. If not given, exports \
     all projects."
  in
  C.Arg.(value @@ opt (some string) None @@ info [ "project" ] ~doc)
;;

let date =
  let parse s =
    try K.Date.from_string_exn s |> Result.ok with
    | K.Date.Date_format_error s -> Error (`Msg s)
  in
  let str = Printf.sprintf in
  let err_str s = str "+%s" (K.Date.to_html5_string s) in
  let print ppf p = Format.fprintf ppf "%s" (err_str p) in
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

let timesheet_t =
  C.Term.(
    const timesheet
    $ api_url
    $ api_user
    $ api_pwd
    $ begin_date
    $ end_date
    $ project_name)
;;

let timesheet_cmd =
  let info = C.Cmd.info "timesheet" in
  C.Cmd.v info timesheet_t
;;

let percentage_t =
  C.Term.(
    const percentage $ api_url $ api_user $ api_pwd $ begin_date $ end_date)
;;

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
