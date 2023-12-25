type t =
  { id : int
  ; name : string
  }

let make id name = { id; name }
let id { id; _ } = id
let name { name; _ } = name

module D = Decoder.Yojson.Safe

let ( let* ) = D.bind

let decoder =
  let* id = D.field "id" D.int in
  let* name = D.field "name" D.string in
  D.return { id; name }
;;

let list_decoder = D.list decoder
let api_get = Api.make_api_get_request "/projects" list_decoder
