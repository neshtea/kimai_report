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

module type REQUEST_CFG = sig
  val api_url : string
  val api_user : string
  val api_pwd : string
end

let make_request_cfg api_url api_user api_pwd =
  (module struct
    let api_url = api_url
    let api_user = api_user
    let api_pwd = api_pwd
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

type 'a body_decoder = 'a Decoder.Yojson.Safe.decoder
type body_encoder = Encoder.Yojson.Encoder.encoder

type 'a request_method =
  | Get of 'a body_decoder
  | Post of (body_encoder * 'a body_decoder)

type endpoint = string
type request_args = (string * string) list

let make_request_args args = args

type 'a api_request =
  | Api_request of ('a request_method * endpoint * request_args)

let make_api_request request_method endpoint args =
  Api_request (request_method, endpoint, args)
;;

let make_api_get_request ?(args = []) endpoint body_decoder =
  make_api_request (Get body_decoder) endpoint args
;;

let make_api_post_request ?(args = []) endpoint body_encoder body_decoder =
  make_api_request (Post (body_encoder, body_decoder)) endpoint args
;;

module Response_error = struct
  type t =
    | Http_error of (int * string)
    | Json_decoder_error of Decoder.Yojson.Safe.Error.t

  let show = function
    | Http_error (status_code, body) ->
      Printf.sprintf "HTTP status code %i: %s" status_code body
    | Json_decoder_error err -> Decoder.Yojson.Safe.Error.show err
  ;;
end

let ( --> ) m json_body_fn =
  let ( >>= ) = Lwt.bind in
  let ( >|= ) = Lwt.Infix.( >|= ) in
  m
  >>= fun (response, body) ->
  let status_code = Cohttp.(Response.status response |> Code.code_of_status) in
  let lwt_string_body = Cohttp_lwt.Body.to_string body in
  if Cohttp.Code.is_success status_code
  then (
    let decoded =
      lwt_string_body
      >|= fun body -> Yojson.Safe.from_string body |> json_body_fn
    in
    decoded
    >>= fun maybe_decoded ->
    match maybe_decoded with
    | Error err -> Lwt.return_error (Response_error.Json_decoder_error err)
    | Ok ok -> Lwt.return_ok ok)
  else
    lwt_string_body
    >>= fun body ->
    Lwt.return_error (Response_error.Http_error (status_code, body))
;;

let encode_body body_encoder = Cohttp_lwt.Body.of_string (body_encoder ())

let run_request (module RC : REQUEST_CFG) = function
  | Api_request (request_method, endpoint, args) ->
    let headers = request_headers RC.api_user RC.api_pwd in
    let uri =
      Uri.add_query_params'
        (Printf.sprintf "%s%s" RC.api_url endpoint |> Uri.of_string)
        args
    in
    let module C = Cohttp_lwt_unix.Client in
    (match request_method with
     | Get body_decoder -> C.get ~headers uri --> body_decoder
     | Post (body_encoder, body_decoder) ->
       let body = encode_body body_encoder in
       C.post ~body ~headers uri --> body_decoder)
;;

let return x = Lwt.return_ok x

let bind m f =
  Lwt.bind m (function
    | Ok ok -> f ok
    | Error err -> Lwt.return_error err)
;;
