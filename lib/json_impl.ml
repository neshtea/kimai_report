module type S = sig
  type t

  val show : t -> string
  val match_string : t -> string option
  val match_float : t -> float option
  val match_int : t -> int option
  val match_bool : t -> bool option
  val match_list : t -> t list option
  val match_field : string -> t -> t option
end

module Yojson_safe : S with type t = Yojson.Safe.t = struct
  type t = Yojson.Safe.t

  let show = Yojson.Safe.show

  let match_string = function
    | `String value -> Some value
    | _ -> None
  ;;

  let match_float = function
    | `Float value -> Some value
    | _ -> None
  ;;

  let match_int = function
    | `Int i -> Some i
    | _ -> None
  ;;

  let match_bool = function
    | `Bool value -> Some value
    | _ -> None
  ;;

  let match_list = function
    | `List value -> Some value
    | _ -> None
  ;;

  let match_field name json =
    match Yojson.Safe.Util.member name json with
    | `Null -> None
    | json -> Some json
  ;;
end

module Yojson_basic : S with type t = Yojson.Basic.t = struct
  type t = Yojson.Basic.t

  let show = Yojson.Basic.show

  let match_string = function
    | `String value -> Some value
    | _ -> None
  ;;

  let match_float = function
    | `Float value -> Some value
    | _ -> None
  ;;

  let match_int = function
    | `Int value -> Some value
    | _ -> None
  ;;

  let match_bool = function
    | `Bool value -> Some value
    | _ -> None
  ;;

  let match_list = function
    | `List value -> Some value
    | _ -> None
  ;;

  let match_field name json =
    match Yojson.Basic.Util.member name json with
    | `Null -> None
    | json -> Some json
  ;;
end
