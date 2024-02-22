module type S = sig
  type elt [@@deriving show, eq]
  type encoder = unit -> string

  val to_string : elt -> encoder
end

(** Implementations of the encoder for Yojson. *)
module Yojson : sig
  (** Implementation of the encoder for values of type
      [Yojson.Basic.t]. *)
  module Encoder : S with type elt = Json_impl.Yojson_encode.t
end
