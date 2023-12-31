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
