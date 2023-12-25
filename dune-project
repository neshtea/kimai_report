(lang dune 3.11)

(name kimai_report)

(generate_opam_files true)

(source
 (github neshtea/kimai_report))

(authors "Marco Schneider <marco.schneider@posteo.de")

(maintainers "Marco Schneider <marco.schneider@posteo.de>")

(license LICENSE)

(documentation https://url/to/documentation)

(package
 (name kimai_report)
 (synopsis "A short synopsis")
 (description "A longer description")
 (depends (ocaml (>= 4.08.0))
          (dune (>= 3.11))
	  ptime ptime.clock.os lwt yojson cohttp cohttp-lwt cohttp-lwt-unix)
 (tags
  (topics "to describe" your project)))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/dune-files.html#dune-project
