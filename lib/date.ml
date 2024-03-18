type t =
  { year : int
  ; month : int
  ; day : int
  }

exception Date_format_error of string

let from_string_exn date_string =
  try
    match Str.split (Str.regexp "-") date_string |> List.map int_of_string with
    | [ year; month; day ] ->
      let valid_year = 1900 <= year && year <= 2100 in
      let valid_month = 1 <= month && month <= 12 in
      let valid_day = 1 <= day && day <= 31 in
      if valid_year && valid_month && valid_day
      then { year; month; day }
      else raise (Date_format_error date_string)
    | _ -> raise (Date_format_error date_string)
  with
  | _ -> raise @@ Date_format_error date_string
;;

let to_html5_string { year; month; day } =
  (* SEE
     https://github.com/kimai/kimai/blob/main/src/API/TimesheetController.php#L89
     for the weird formatting *)
  Printf.sprintf "%04d-%02d-%02d" year month day
;;

let to_html5_start_of_day_string { year; month; day } =
  Printf.sprintf "%04d-%02d-%02dT00:00:00" year month day
;;

let to_html5_end_of_day_string { year; month; day } =
  Printf.sprintf "%04d-%02d-%02dT23:59:59" year month day
;;

let of_ptime pt =
  let year, month, day = Ptime.to_date pt in
  { year; month; day }
;;

let today () = Ptime_clock.now () |> of_ptime

let start_of_month () =
  let { year; month; _ } = today () in
  { year; month; day = 1 }
;;

let end_of_month () =
  let { year; month; _ } = today () in
  let { year; month; day } =
    { year = (if month = 12 then year + 1 else year)
    ; month = (if month = 12 then 1 else month + 1)
    ; day = 1
    }
  in
  let one_s = Ptime.Span.of_int_s 1 in
  let timestamp_first_of_month =
    match Ptime.of_date_time ((year, month, day), ((0, 0, 0), 0)) with
    | None ->
      raise
        (Date_format_error
           (Printf.sprintf "timestamp first of month %d-%d-%d" year month day))
    | Some timestamp -> timestamp
  in
  let timestamp_end_of_month =
    match Ptime.sub_span timestamp_first_of_month one_s with
    | None ->
      raise
        (Date_format_error
           (Printf.sprintf "timestamp end of month %d-%d-%d" year month day))
    | Some timestamp -> timestamp
  in
  of_ptime timestamp_end_of_month
;;
