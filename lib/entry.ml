type t =
  { date : Ptime.t
  ; duration : float
  ; activity : int option
  ; description : string option
  ; project : int option
  }

let date { date; _ } = date
let project { project; _ } = project
let duration { duration; _ } = duration
let description { description; _ } = description
let with_description t description = { t with description }
let activity { activity; _ } = activity

let split_timestamp s =
  match Str.split (Str.regexp "T") s with
  | [] -> ""
  | x :: _ -> x
;;

let date_string { date; _ } = Ptime.to_rfc3339 date |> split_timestamp

module D = Decoder.Yojson.Safe

let decoder =
  let open D.Syntax in
  let* date = D.field "begin" Api.timestamp_decoder in
  let* description = D.optional @@ D.field "description" D.string in
  let* activity = D.optional @@ D.field "activity" D.int in
  let* duration' = D.field "duration" D.int in
  let duration = float_of_int duration' /. 60. /. 60. in
  let* project = D.optional @@ D.field "project" D.int in
  D.return { date; duration; activity; description; project }
;;
