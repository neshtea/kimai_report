let ptime_of_string s =
  match Ptime.of_rfc3339 s with
  | Ok (t, _, _) -> Some t
  | Error _ -> None
;;

exception Format_error of string

let ptime_of_string_exn s =
  match ptime_of_string s with
  | Some t -> t
  | None -> raise @@ Format_error s
;;

let timestamp_decoder =
  let module D = Decoder.Yojson.Safe in
  D.map (fun s -> ptime_of_string_exn s) D.string
;;

(* the reporting monad *)
module Monad = struct
  type 'a m
end

type request_cfg =
  { api_url : string
  ; api_user : string
  ; api_pwd : string
  }

let make_request_cfg api_url api_user api_pwd = { api_url; api_user; api_pwd }

module type REQUEST_CFG = sig
  val api_url : string
  val api_user : string
  val api_pwd : string
  val record : request_cfg
end

let make_request_cfg_m api_url api_user api_pwd =
  (module struct
    let api_url = api_url
    let api_user = api_user
    let api_pwd = api_pwd
    let record = make_request_cfg api_url api_user api_pwd
  end : REQUEST_CFG)
;;

let request_headers api_user api_pwd =
  let module H = Cohttp.Header in
  H.add_list
    (H.init ())
    [ "X-AUTH-USER", api_user
    ; "X-AUTH-TOKEN", api_pwd
    ; "accept", "application/json"
    ]
;;

type request_method = GET
type endpoint = string

type 'a api_request =
  | Api_request of
      (request_method
      * endpoint
      * (string * string) list
      * 'a Decoder.Yojson.Safe.decoder)

let make_api_request request_method endpoint args request_decoder =
  Api_request (request_method, endpoint, args, request_decoder)
;;

let make_api_get_request ?(args = []) endpoint request_decoder =
  make_api_request GET endpoint args request_decoder
;;

let request request_method endpoint { api_url; api_user; api_pwd } =
  let headers = request_headers api_user api_pwd in
  let uri = Printf.sprintf "%s%s" api_url endpoint |> Uri.of_string in
  let module C = Cohttp_lwt_unix.Client in
  match request_method with
  | GET -> C.get ~headers uri
;;

let ( --> ) m json_body_fn =
  let ( >>= ) = Lwt.bind in
  let ( >|= ) = Lwt.Infix.( >|= ) in
  m
  >>= fun (_, body) ->
  Cohttp_lwt.Body.to_string body
  >|= fun body -> Yojson.Safe.from_string body |> json_body_fn
;;

let run_request { api_url; api_user; api_pwd } = function
  | Api_request (request_method, endpoint, args, request_decoder) ->
    let headers = request_headers api_user api_pwd in
    let uri =
      Uri.add_query_params'
        (Printf.sprintf "%s%s" api_url endpoint |> Uri.of_string)
        args
    in
    let module C = Cohttp_lwt_unix.Client in
    (match request_method with
     | GET -> C.get ~headers uri --> request_decoder)
;;

let bind m f =
  Lwt.bind m (function
    | Ok ok -> f ok
    | Error err -> Lwt.return_error err)
;;
