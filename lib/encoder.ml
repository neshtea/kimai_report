module type S = sig
  type elt [@@deriving show, eq]
  type encoder = unit -> string

  val to_string : elt -> encoder
end

module Make (Y : Json_impl.E) : S with type elt = Y.t = struct
  type elt = Y.t
  type encoder = unit -> string

  let to_string elt _ = Y.to_string elt
end

module Yojson = struct
  module Encoder = Make (Json_impl.Yojson_encode)
end
