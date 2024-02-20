(** The result of fetching a value of the ['a] from the repo can either be an
    asynchronous ['a] or an error message. *)
type 'a or_error = ('a, string) result Lwt.t

(** A repo, defined by a module implementing {!S}, serves as a source for
    generating reports. *)
module type S = sig
  (** [find_projects ()] is a list of all {!Project.t} or an error. *)
  val find_projects : unit -> Project.t list or_error

  (** [find_activities ()] is a list of all {!Activity.t} or an error. *)
  val find_activities : unit -> Activity.t list or_error

  (** [find_timesheet begin_date end_date] is a list of all {!Entry.t} or an
      error between the [begin_date] and [end_date], inclusively. *)
  val find_timesheet : Date.t -> Date.t -> Entry.t list or_error
end

(** Implementation of a repo that, given a {!Api.REQUEST_CFG}, talks directly to
    the kimai instance and fetches objects from the api without an
    intermediary. *)
module Cohttp (_ : Api.REQUEST_CFG) : S

module Bi_lookup : sig
  (** Elements of {!S} have an id and a name. *)
  module type Elt_sig = sig
    (** The type of the values we want to lookup by id/name. *)
    type t

    (** [id t] is the id of [t]. *)
    val id : t -> int

    (** [name t] is the name of [t]. *)
    val name : t -> string
  end

  (** Generic interface to convert between names and ids of elements. *)
  module type S = sig
    (** Type of the lookup. *)
    type t

    (** Type of elements being looked up. *)
    type elt

    (** [make es] is a bi-directional lookup between element ids and their
        names. *)
    val make : elt list -> t

    (** [by_name name lookup] find some elt by its name or nothing. *)
    val by_name : string -> t -> elt option

    (** [by_id id lookup] find some elt by its id or nothing. *)
    val by_id : int -> t -> elt option
  end

  (** Functor that implements {!S} for some {!Elt_sig} with an underlying
      map. *)
  module Map (E : Elt_sig) : S with type elt = E.t

  (** Functor that implements {!S} for some {!Elt_sig} with an underlying
      {!Hashtbl.t}. *)
  module Hash (E : Elt_sig) : S with type elt = E.t
end

(** Functor that provides common utilities for things in a repo of type
    {!S}. Requires a repo of type {!S} and a bi-lookup functor from a
    {!Bi_lookup.Elt_sig} to a {!Bi_lookup.S}.

    {[
      let _ =
        let module R : S = ... in
        let module RU = Repo_utils (R) (Bi_lookup.Map) in
        RU.by_id (module Project) 42
    ]}
    ``` *)
module Repo_utils
    (_ : S)
    (_ : functor (E : Bi_lookup.Elt_sig) -> Bi_lookup.S with type elt = E.t) : sig
  include S

  (** [id_by_name (module Elt) elems name] is some elt of a list of elems where
      each elem is an Elt, identified by it's name. *)
  val by_name
    :  (module Bi_lookup.Elt_sig with type t = 'a)
    -> 'a list
    -> string
    -> 'a option

  (** [name_by_id (module Elt) elems id] is some elt from a list of elems where
      each elem is an Elt, identified by it's id. *)
  val by_id
    :  (module Bi_lookup.Elt_sig with type t = 'a)
    -> 'a list
    -> int
    -> 'a option
end
