type t

val id : t -> int
val name : t -> string

(** [decoder yojson] decodes a {!Yojson.Safe.t} into a {!t}. *)
val decoder : t Decoder.Yojson.Safe.decoder
