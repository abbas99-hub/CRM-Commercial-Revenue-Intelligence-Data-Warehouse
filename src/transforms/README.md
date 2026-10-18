# Silver transforms

SQL Server is the transformation engine for this project. Execute the SQL scripts in `sql/02_silver/` after loading Phase 3 Bronze tables. The transform prioritizes opportunities and target reconciliation. Python is reserved for repeatable local validation and test orchestration, not for silently modifying source files.
