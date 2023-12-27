module Timesheet : sig
  val exec
    :  ?project_name:string option
    -> (module Repo.S)
    -> Date.t
    -> Date.t
    -> Entry.t list Repo.or_error

  val print_csv : Entry.t list -> unit
end

module Percentage : sig
  val exec
    :  (module Repo.S)
    -> Date.t
    -> Date.t
    -> (string * (int * float * int)) list Repo.or_error

  val print_csv : (string * (int * float * int)) list -> unit
end
