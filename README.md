Yes, this could have been a shell-script.

# kimai_report

Utilities to generate reports for company controlling from a
[Kimai](https://www.kimai.cloud/) instance.  It is assumed you have API-access
to your instance.  You need

- to know the api endpoint (i.e. `https://<username>.kimai.cloud/api`)
- the username or user email that is allowed to connect to the api
- the password for that user

For more information, see [the Kimai API
quickstart](https://www.kimai.org/documentation/rest-api.html).

## Utilities

### `timesheet`

Generate a timesheet.  Optionally, generate it for one project (by name).

### `percentage`

Generate the percentages (projects to logged time spent on these projects).

### `working_time`

Generate a working-time report.

### `server`

A small webclient for fetching and displaying reports.

### `record`

Record a timesheet entry.

## Usage

You can either check out this repo and use the nix build yourself or run it
directly via

```shell
# Show help
$ nix run github:neshtea/kimai_report -- --help

# Generate timesheet report
$ nix run github:neshtea/kimai_report -- timesheet https://<username>.kimai.cloud/api user@host.org super_secure_password

# Generate timesheet report for a specific project (by project name), begin and end (inclusively)
$ nix run github:neshtea/kimai_report -- timesheet https://<username>.kimai.cloud/api user@host.org super_secure_password --project my-project-name --begin 2023-12-01 --end 2023-12-23
2023-12-12,1.000000,"Projektverwaltung"
2023-12-13,2.000000,"Tickets 529, 530"
2023-12-14,0.500000,"Recherche: Docker Registry"
2023-12-14,1.500000,"Tickets 514, 533, 535"
2023-12-15,1.000000,"Tickets 539"
2023-12-15,1.500000,"Tickets 539, 541, 542"
2023-12-15,1.000000,"Tickets 522, 534"
2023-12-18,4.000000,"Tickets 506, 511, 534, 535, 543"
2023-12-18,2.000000,"Tickets 526, 543"
2023-12-19,1.000000,"Tickets 543"
2023-12-20,2.000000,"Tickets 543"
2023-12-21,1.500000,"Tickets 528 (Nacharbeit), 540"
2023-12-21,1.000000,"Releaseplanung 1.4.0."
2023-12-21,2.500000,"Tickets 523, 544, Release 1.4.0"
2023-12-21,0.500000,"Release 1.4.0"
2023-12-22,2.000000,"Release 1.4.1 (CMDB-Report Hotfix)"

# Generate a percentages report
$ nix run github:neshtea/kimai_report -- percentage https://<username>.kimai.cloud/api user@host.org super_secure_password --begin 2023-12-01 --end 2023-12-31
Internal,12h,16.845878%,17%
Project_A,6h,8.602151%,9%
Project_B,25h,35.842294%,36%
Project_B (unbillable),11h,15.770609%,16%
Project_C,3h,4.301075%,4%
Consulting,4h,5.734767%,6%
Consulting (unbillable),9h,12.903226%,13%
```
