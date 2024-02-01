module D = Dream_html

module View = struct
  module H = Dream_html.HTML
  module Hx = Dream_html.Hx

  let timesheets_report_form () =
    let start_of_month, today =
      ( Date.start_of_month () |> Date.to_html5_string ~with_clock:false
      , Date.today () |> Date.to_html5_string ~with_clock:false )
    in
    H.section
      []
      [ H.h2 [] [ D.txt "Timesheets Report" ]
      ; H.form
          [ H.method_ `GET; H.action "/timesheets" ]
          [ H.label [ H.for_ "begin" ] [ D.txt "Begin" ]
          ; H.input
              [ H.id "begin"
              ; H.name "begin"
              ; H.type_ "date"
              ; H.value "%s" start_of_month
              ]
          ; H.label [ H.for_ "end" ] [ D.txt "End" ]
          ; H.input
              [ H.id "end"; H.name "end"; H.type_ "date"; H.value "%s" today ]
          ; H.label [ H.for_ "project" ] [ D.txt "Project" ]
          ; H.input [ H.id "project"; H.name "project"; H.type_ "text" ]
          ; H.button [ H.type_ "submit" ] [ D.txt "Run" ]
          ]
      ]
  ;;

  let timesheets_report_table report =
    print_endline @@ Printf.sprintf "length %i" @@ List.length report;
    H.div
      []
      [ H.p
          []
          [ D.txt "Overall duration: %fh"
            @@ Report.Timesheet.overall_duration report
          ]
      ; H.table
          []
          [ H.thead
              []
              [ H.th [] [ D.txt "Date" ]
              ; H.th [] [ D.txt "Hours" ]
              ; H.th [] [ D.txt "Description" ]
              ]
          ; H.body
              []
              (List.map
                 (fun entry ->
                   H.tr
                     []
                     [ H.td
                         []
                         [ D.txt
                             "%s"
                             (Entry.date entry
                              |> Date.of_ptime
                              |> Date.to_html5_string ~with_clock:false)
                         ]
                     ; H.td [] [ D.txt "%f" @@ Entry.duration entry ]
                     ; H.td
                         []
                         [ D.txt "%s"
                           @@ Option.value ~default:""
                           @@ Entry.description entry
                         ]
                     ])
                 report)
          ]
      ]
  ;;

  let percentage_report_form () =
    let start_of_month, today =
      ( Date.start_of_month () |> Date.to_html5_string ~with_clock:false
      , Date.today () |> Date.to_html5_string ~with_clock:false )
    in
    H.section
      []
      [ H.h2 [] [ D.txt "Percentage Report" ]
      ; H.form
          [ H.method_ `GET; H.action "/percentage" ]
          [ H.label [ H.for_ "begin" ] [ D.txt "Begin" ]
          ; H.input
              [ H.id "begin"
              ; H.name "begin"
              ; H.type_ "date"
              ; H.value "%s" start_of_month
              ]
          ; H.label [ H.for_ "end" ] [ D.txt "End" ]
          ; H.input
              [ H.id "end"; H.name "end"; H.type_ "date"; H.value "%s" today ]
          ; H.button [ H.type_ "submit" ] [ D.txt "Run" ]
          ]
      ]
  ;;

  let percentage_report_table report =
    H.table
      []
      [ H.thead
          []
          [ H.th [] [ D.txt "Project Name" ]
          ; H.th [] [ D.txt "Overall Hours" ]
          ; H.th [] [ D.txt "Percentage (exact)" ]
          ; H.th [] [ D.txt "Percentage (rounded)" ]
          ]
      ; H.body
          []
          (List.map
             (fun (project_name, (overall_hours, percentage, percentage_rounded)) ->
               H.tr
                 []
                 [ H.td [] [ D.txt "%s" project_name ]
                 ; H.td [] [ D.txt "%i" overall_hours ]
                 ; H.td [] [ D.txt "%f" percentage ]
                 ; H.td [] [ D.txt "%i" percentage_rounded ]
                 ])
             report)
      ]
  ;;

  let index timesheets_report percentage_report =
    H.html
      [ H.lang "en" ]
      [ H.head [] [ H.title [] "kimai_report web" ]
      ; H.body
          []
          [ H.h1 [] [ D.txt "kimai_report web" ]
          ; timesheets_report_form ()
          ; (match timesheets_report with
             | None -> H.null []
             | Some report -> timesheets_report_table report)
          ; percentage_report_form ()
          ; (match percentage_report with
             | None -> H.null []
             | Some report -> percentage_report_table report)
          ]
      ]
  ;;
end

module Route = struct
  let handle_get_index _req = View.index None None |> Dream_html.respond
  let ( let* ) = Lwt.bind

  let date_or ~default o =
    match o with
    | None | Some "" -> default
    | Some s -> Date.from_string_exn s
  ;;

  let begin_date begin_ = date_or ~default:(Date.start_of_month ()) begin_
  let end_date end_ = date_or ~default:(Date.today ()) end_

  let handle_get_percentage (module R : Repo.S) req =
    let begin_ = Dream.query req "begin" in
    let end_ = Dream.query req "end" in
    let* lwt_report =
      Report.Percentage.exec (module R) (begin_date begin_) (end_date end_)
    in
    match lwt_report with
    | Ok report -> View.index None (Some report) |> Dream_html.respond
    | Error err -> Dream.html ~status:`Internal_Server_Error err
  ;;

  let handle_get_timesheets (module R : Repo.S) req =
    let begin_ = Dream.query req "begin" in
    let end_ = Dream.query req "end" in
    let project_name = Dream.query req "project" in
    let* lwt_report =
      Report.Timesheet.exec
        (module R)
        (begin_date begin_)
        (end_date end_)
        ~project_name
    in
    match lwt_report with
    | Ok report -> View.index (Some report) None |> Dream_html.respond
    | Error err -> Dream.html ~status:`Internal_Server_Error err
  ;;

  let routes repo =
    [ Dream.get "/" handle_get_index
    ; Dream.get "/percentage" (handle_get_percentage repo)
    ; Dream.get "/timesheets" (handle_get_timesheets repo)
    ]
  ;;
end

let start_server (module R : Repo.S) port =
  Dream.run ~port
  @@ Dream.logger
  @@ Dream.memory_sessions
  @@ Dream.router (Route.routes (module R : Repo.S))
;;
