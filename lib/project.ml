type t =
  { id : int
  ; name : string
  ; customer : int
  }

let id { id; _ } = id
let name { name; _ } = name
let customer { customer; _ } = customer

module D = Decoder.Yojson.Safe

let ( let* ) = D.bind

let decoder =
  let* id = D.field "id" D.int in
  let* name = D.field "name" D.string in
  let* customer = D.field "customer" D.int in
  D.return { id; name; customer }
;;

let encoder name customer =
  let project =
    `Assoc
      [ "name", `String name
      ; "customer", `Int customer
      ; "visible", `Bool true
      ; "billable", `Bool true
      ; "globalActivities", `Bool true
      ]
  in
  Encoder.Yojson.Encoder.to_string project
;;
