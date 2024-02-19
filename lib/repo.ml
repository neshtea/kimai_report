type 'a or_error = ('a, string) result Lwt.t
(* not sure if I wan to have the Lwt async in the signature. *)

let or_error_string m =
  let ( >>= ) = Lwt.bind in
  m
  >>= function
  | Error err -> Api.Response_error.show err |> Lwt.return_error
  | Ok projects -> Lwt.return_ok projects
;;

module type S = sig
  val find_projects : unit -> Project.t list or_error
  val find_activities : unit -> Activity.t list or_error
  val find_timesheet : Date.t -> Date.t -> Entry.t list or_error
end

module Cohttp (RC : Api.REQUEST_CFG) : S = struct
  module D = Decoder.Yojson.Safe

  let run api_request =
    Api.run_request (module RC) api_request |> or_error_string
  ;;

  let find_projects () =
    D.list Project.decoder |> Api.make_api_get_request "/projects" |> run
  ;;

  let find_activities () =
    D.list Activity.decoder |> Api.make_api_get_request "/activities" |> run
  ;;

  let find_timesheet begin_date end_date =
    D.list Entry.decoder
    |> Api.make_api_get_request
         ~args:
           [ "begin", Date.to_html5_string begin_date
           ; "end", Date.to_html5_string end_date
           ; "size", "1000"
             (* NOTE: I don't think we'll ever have that many entries in a
                particular range, but the default (NULL) is too low. *)
           ]
         "/timesheets"
    |> run
  ;;
end
