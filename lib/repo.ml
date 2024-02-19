type 'a or_error = ('a, string) result Lwt.t
(* not sure if I wan to have the Lwt async in the signature. *)

let or_error_string m =
  let ( >>= ) = Lwt.bind in
  m
  >>= function
  | Error err -> Decoder.Yojson.Safe.Error.show err |> Lwt.return_error
  | Ok projects -> Lwt.return_ok projects
;;

module type S = sig
  val find_projects : unit -> Project.t list or_error
  val find_activities : unit -> Activity.t list or_error
  val find_timesheet : Date.t -> Date.t -> Entry.t list or_error
end

module Cohttp (RC : Api.REQUEST_CFG) : S = struct
  module D = Decoder.Yojson.Safe

  let run api_request =
    Api.run_request (module RC) api_request |> or_error_string
  ;;

  let find_projects () =
    D.list Project.decoder |> Api.make_api_get_request "/projects" |> run
  ;;

  let find_activities () =
    D.list Activity.decoder |> Api.make_api_get_request "/activities" |> run
  ;;

  let find_timesheet begin_date end_date =
    D.list Entry.decoder
    |> Api.make_api_get_request
         ~args:
           [ "begin", Date.to_html5_string begin_date
           ; "end", Date.to_html5_string end_date
           ; "size", "1000"
             (* NOTE: I don't think we'll ever have that many entries in a
                particular range, but the default (NULL) is too low. *)
           ]
         "/timesheets"
    |> run
  ;;
end

module Bi_lookup = struct
  module type Elt_sig = sig
    type t

    val id : t -> int
    val name : t -> string
  end

  module type S = sig
    type t
    type elt

    val make : elt list -> t
    val by_name : string -> t -> elt option
    val by_id : int -> t -> elt option
  end

  module Map (E : Elt_sig) : S with type elt = E.t = struct
    module SM = Map.Make (String)
    module IM = Map.Make (Int)

    type elt = E.t

    type t =
      { by_name : elt SM.t
      ; by_id : elt IM.t
      }

    let make elements =
      { by_name =
          List.fold_left (fun m p -> SM.add (E.name p) p m) SM.empty elements
      ; by_id =
          List.fold_left (fun m p -> IM.add (E.id p) p m) IM.empty elements
      }
    ;;

    let by_name name { by_name; _ } = SM.find_opt name by_name
    let by_id id { by_id; _ } = IM.find_opt id by_id
  end
end

module Repo_utils
    (R : S)
    (Make_container : functor
       (E : Bi_lookup.Elt_sig)
       -> Bi_lookup.S with type elt = E.t) =
struct
  include R

  let by_name
    (type a)
    (module E : Bi_lookup.Elt_sig with type t = a)
    (things : a list)
    name
    =
    let module Container = Make_container (E) in
    Container.make things |> Container.by_name name
  ;;

  let by_id
    (type a)
    (module E : Bi_lookup.Elt_sig with type t = a)
    (things : a list)
    id
    =
    let module Container = Make_container (E) in
    Container.make things |> Container.by_id id
  ;;
end
