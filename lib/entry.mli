type t

val date : t -> Ptime.t
val duration : t -> float
val activity : t -> int option
val description : t -> string option
val with_description : t -> string option -> t
val project : t -> int option
val date_string : t -> string
val decoder : t Decoder.Yojson.Safe.decoder
