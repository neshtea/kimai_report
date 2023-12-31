module Timesheet : sig
  (** [exec ~project_name (module R) begin_date end_date] is a list of all
      timesheet entries between [begin_date] and [end_date] (inclusively) or a
      string error. *)
  val exec
    :  ?project_name:string option
    -> (module Repo.S)
    -> Date.t
    -> Date.t
    -> Entry.t list Repo.or_error

  (** [print_csv pairs] prints all timesheet entries to stdout. *)
  val print_csv : Entry.t list -> unit
end

module Percentage : sig
  (** [exec (module R) begin_date end_date] is a list of pairs, mapping project
      names to percentages. Includes everything between [begin_date] and
      [end_date] (inclusively) or a string error. *)
  val exec
    :  (module Repo.S)
    -> Date.t
    -> Date.t
    -> (string * (int * float * int)) list Repo.or_error

  (** [print_csv pairs] prints all percentages to stdout. *)
  val print_csv : (string * (int * float * int)) list -> unit
end
