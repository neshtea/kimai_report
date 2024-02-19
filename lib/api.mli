val timestamp_decoder : Ptime.t Decoder.Yojson.Safe.decoder

(** Modules that implement the {!REQUEST_CFG} signature can be used to define
    the configuration for an api connection. *)
module type REQUEST_CFG = sig
  val api_url : string
  val api_user : string
  val api_pwd : string
end

(** [make_request_cfg api_url api_user api_pwd] is a module that implements the
    {!REQUEST_CFG} signature. *)
val make_request_cfg : string -> string -> string -> (module REQUEST_CFG)

(** [request_args] are additional arguments that can be fed to an {!api_request}
    to provide additional arguments to the request. *)
type request_args

(** [make_request_args args] is a {!request_args}. *)
val make_request_args : (string * string) list -> request_args

(** An [a api_request] is a request that, when executed, returns a value of type
    [a] or an error. The [api_request] is only a data object and causes no
    side-effects. *)
type 'a api_request

(** An [response_error] is a failed response of a certain type. *)
module Response_error : sig
  type t =
    | Http_error of (int * string)
    | Json_decoder_error of Decoder.Yojson.Safe.Error.t

  val show : t -> string
end

(** [make_api_get_request ~args endpoint decoder] is a new {!api_request}
    against the provided [endpoint] unsing the HTTP-GET method. It decodes the
    result using the provided [decoder]. Additional [~args] may be provided
    which will be added as parameters to the request. The request must be run
    via {!run_request}. *)
val make_api_get_request
  :  ?args:(string * string) list
  -> string
  -> 'a Decoder.Yojson.Safe.decoder
  -> 'a api_request

(** [make_api_post_request ~args endpoint body decoder] is a new {!api_request}
    against the provided [endpoint] unsing the HTTP-POST method with provided
    [body]. It decodes the result using the provided [decoder]. Additional
    [~args] may be provided which will be added as parameters to the
    request. The request must be run via {!run_request}. *)
val make_api_post_request
  :  ?args:(string * string) list
  -> string
  -> string
  -> 'a Decoder.Yojson.Safe.decoder
  -> 'a api_request

(** [run_request (module Rc) req] actually runs the request [req], using the
    provided credentials in the request config [Rc].  The result is either a
    value of type [a] or a decoder error, wrapped in a {!Lwt.t} result. *)
val run_request
  :  (module REQUEST_CFG)
  -> 'a api_request
  -> ('a, Response_error.t) result Lwt.t

(** [return x] is the value [x] lifted into the {!Result.t} monad, wrapped into
    the {!Lwt.t} monad. *)
val return : 'a -> ('a, 'b) result Lwt.t

(** [bind m f] binds the concurrent result of m to f. Terminates early if the
    result is an {!Error}. *)
val bind
  :  ('a, 'b) result Lwt.t
  -> ('a -> ('c, 'b) result Lwt.t)
  -> ('c, 'b) result Lwt.t
