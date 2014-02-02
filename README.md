mapnik-query-analyzer
=====================

Shellscript for analysing postgresql logfiles for Mapnik speed tuning

you have to feed it a postgresql logfile with 
* log_line_prefix = '%m '
* log_min_duration_statement = 0 
