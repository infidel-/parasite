Use these rules for all report-generation skills:

- never run tests after generating a report
- rewrite old report file contents directly; do not patch incrementally
- start each generated report with the generation date and time
- give each table a clear title
- sort all table rows alphabetically by the first column
- after generating a report, run `make report` to copy report files to the destination location
