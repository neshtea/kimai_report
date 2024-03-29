module D = Dream_html

module View = struct
  module H = Dream_html.HTML
  module Hx = Dream_html.Hx

  let labelled_input ?(input_value = None) label input_id input_type =
    [ H.label [ H.for_ "%s" input_id ] [ D.txt "%s" label ]
    ; H.input
        ((match input_value with
          | None -> []
          | Some v -> [ H.value "%s" v ])
         @ [ H.type_ input_type; H.id "%s" input_id; H.name "%s" input_id ])
    ]
  ;;

  let form method_ action result_target result_swap inputs =
    H.form
      [ H.method_ method_
      ; H.action action
      ; (match method_ with
         | `GET -> Hx.get action
         | `POST -> Hx.post action)
      ; Hx.target result_target
      ; Hx.swap
          (match result_swap with
           | `Inner_html -> "innerHTML"
           | `Outer_html -> "outerHTML")
      ]
      inputs
  ;;

  let timesheets_report_form () =
    let start_of_month, today =
      ( Date.start_of_month () |> Date.to_html5_string
      , Date.today () |> Date.to_html5_string )
    in
    H.section
      []
      [ H.h2 [] [ D.txt "Timesheets Report" ]
      ; form `GET "/timesheets" "#timesheets_report_table" `Outer_html
        @@ List.concat
             [ labelled_input
                 "Begin"
                 "begin"
                 "date"
                 ~input_value:(Some start_of_month)
             ; labelled_input "End" "end" "date" ~input_value:(Some today)
             ; labelled_input "Project" "project" "text"
             ]
        @ [ H.button [ H.type_ "submit" ] [ D.txt "Run" ] ]
      ]
  ;;

  let th txt = H.th [] [ D.txt "%s" txt ]
  let tr tds = H.tr [] tds
  let td txt = H.td [] [ D.txt "%s" txt ]

  let tdf float =
    H.td [ D.string_attr "style" "text-align:right" ] [ D.txt "%.2f" float ]
  ;;

  let tdi int =
    H.td [ D.string_attr "style" "text-align:right" ] [ D.txt "%d" int ]
  ;;

  let timesheets_report_table report =
    H.div
      [ H.id "timesheets_report_table" ]
      [ H.p
          []
          [ D.txt "Overall duration: %.2fh"
            @@ Report.Timesheet.overall_duration report
          ]
      ; H.table
          []
          [ H.thead [] [ th "Date"; th "Duration"; th "Description" ]
          ; H.body
              []
              (List.map
                 (fun entry ->
                   tr
                     [ td
                         (Entry.date entry
                          |> Date.of_ptime
                          |> Date.to_html5_string)
                     ; tdf @@ Entry.duration entry
                     ; td @@ Option.value ~default:"" @@ Entry.description entry
                     ])
                 report)
          ]
      ]
  ;;

  let percentage_report_form () =
    let start_of_month, today =
      ( Date.start_of_month () |> Date.to_html5_string
      , Date.today () |> Date.to_html5_string )
    in
    H.section
      []
      [ H.h2 [] [ D.txt "Percentage Report" ]
      ; form
          `GET
          "/percentage"
          "#percentage_report_table"
          `Outer_html
          (List.concat
             [ labelled_input
                 ~input_value:(Some start_of_month)
                 "Begin"
                 "begin"
                 "date"
             ; labelled_input ~input_value:(Some today) "End" "end" "date"
             ]
           @ [ H.button [ H.type_ "submit" ] [ D.txt "Run" ] ])
      ]
  ;;

  let percentage_report_table report =
    H.table
      [ H.id "percentage_report_table" ]
      [ H.thead
          []
          [ th "Project Name"
          ; th "Overall Hours"
          ; th "Percentage (exact)"
          ; th "Percentage (rounded)"
          ]
      ; H.body
          []
          (List.map
             (fun (project_name, (overall_hours, percentage, percentage_rounded)) ->
               tr
                 [ td project_name
                 ; tdi overall_hours
                 ; tdf percentage
                 ; tdi percentage_rounded
                 ])
             report)
      ]
  ;;

  let index timesheets_report percentage_report =
    H.html
      [ H.lang "en" ]
      [ H.head [] [ H.title [] "kimai_report web" ]
      ; H.body
          [ Hx.boost true ]
          [ H.script [ H.src "https://unpkg.com/htmx.org@1.9.10" ] ""
          ; H.h1 [] [ D.txt "kimai_report web" ]
          ; timesheets_report_form ()
          ; timesheets_report_table (Option.value ~default:[] timesheets_report)
          ; percentage_report_form ()
          ; percentage_report_table (Option.value ~default:[] percentage_report)
          ]
      ]
  ;;

  let error error_text = H.p [] [ D.txt "ERROR: %s" error_text ]
end

module Route = struct
  let is_hx_request req = Dream.has_header req "HX-Request"
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
    | Ok report ->
      if is_hx_request req
      then View.percentage_report_table report |> Dream_html.respond
      else View.index None (Some report) |> Dream_html.respond
    | Error err -> View.error err |> Dream_html.respond
  ;;

  let handle_get_timesheets (module R : Repo.S) req =
    let begin_ = Dream.query req "begin" in
    let end_ = Dream.query req "end" in
    let project_names =
      match Dream.query req "project" with
      | Some project_name ->
        if String.length project_name == 0 then [] else [ project_name ]
      | None -> []
    in
    let* lwt_report =
      Report.Timesheet.exec
        (module R)
        (begin_date begin_)
        (end_date end_)
        ~project_names
    in
    match lwt_report with
    | Ok report ->
      if is_hx_request req
      then View.timesheets_report_table report |> Dream_html.respond
      else View.index (Some report) None |> Dream_html.respond
    | Error err -> View.error err |> Dream_html.respond
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
