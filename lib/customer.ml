type t =
  { id : int
  ; name : string
  }

let id { id; _ } = id
let name { name; _ } = name

module D = Decoder.Yojson.Safe

let ( let* ) = D.bind

let decoder =
  let* id = D.field "id" D.int in
  let* name = D.field "name" D.string in
  D.return { id; name }
;;

let encoder name =
  let customer =
    `Assoc
      [ "name", `String name
      ; "currency", `String "EUR"
      ; "country", `String "DE"
      ; "timezone", `String "Europe/Berlin"
      ; "visible", `Bool true
      ; "billable", `Bool true
      ]
  in
  Encoder.Yojson.Encoder.to_string customer
;;
