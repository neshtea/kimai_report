module Record : sig
  (** [exec ~project_name (module R) begin_date end_date] is a list of all
      timesheet entries between [begin_date] and [end_date] (inclusively) or a
      string error. *)
  val exec
    :  (module Repo.S)
    -> string
    -> string
    -> string
    -> string
    -> string
    -> (bool, string) result Lwt.t
end
