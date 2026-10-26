# SQL class shell

`sqlshell.py` loads every `input/*.csv` into a SQL Server database (`CLASSDB`)
on startup and logs every command and its output to `output/` and
`output/prompt_log.md`.

## One-time setup

1. **Install WSL** (Docker Desktop's Linux engine needs it). In an *admin*
   PowerShell:
   ```powershell
   wsl --install
   ```
   Then reboot.
2. **Install the ODBC driver**: Microsoft ODBC Driver 18 for SQL Server
   (https://learn.microsoft.com/sql/connect/odbc/download-odbc-driver-for-sql-server).
3. **Install the Python package**:
   ```powershell
   pip install pyodbc
   ```
4. **Create the SQL Server container** (once Docker Desktop shows "running"):
   ```powershell
   docker run --name classdb-sql -e ACCEPT_EULA=Y -e "MSSQL_SA_PASSWORD=ClassDb#2026pw" -p 1433:1433 -d mcr.microsoft.com/mssql/server:2022-latest
   ```
   The password is for this local throwaway container only. It must be at
   least 8 characters with upper, lower, digit and symbol.

If `docker` isn't recognised, open a new terminal. Docker's folder is already
on your user PATH, but terminals opened before the install don't see it.

## Every session

1. Start Docker Desktop and wait until it says it's running.
2. Start the container (it already exists after the one-time setup):
   ```powershell
   docker start classdb-sql
   ```
   SQL Server takes about 15 seconds to accept connections.
3. Run the shell:
   ```powershell
   $env:MSSQL_PASSWORD = "ClassDb#2026pw"
   python sqlshell.py            # interactive
   python sqlshell.py script.sql # run a script file
   ```
   ```Bash
   export MSSQL_PASSWORD="ClassDb#2026pw"
   python sqlshell.py            # interactive
   python sqlshell.py script.sql # run a script file
   ```
4. When finished: `docker stop classdb-sql`.

Other settings (all optional): `MSSQL_SERVER` (default `localhost,1433`),
`MSSQL_USER` (`sa`), `MSSQL_DRIVER` (`ODBC Driver 18 for SQL Server`).

## Using the shell

- A batch ends at a line containing only `GO`. A single-line statement ending
  in `;` also runs immediately. Type `exit` to quit.
- `CLASSDB` is dropped and rebuilt from the CSVs on every run, so keep your
  `CREATE TABLE` statements in a script file.
- `CREATE ASSERTION name CHECK (condition);` and `DROP ASSERTION name;` are
  added by the shell (SQL Server has none). Each assertion becomes
  `assert_<name>__<table>` triggers. Definitions are saved to
  `other/assertions.json`.
- User triggers (`CREATE TRIGGER`) are saved to `other/triggers.sql`.

## Folders

| Folder | Contents |
| --- | --- |
| `input/` | CSV files, one table each (file name = table name) |
| `output/` | `NNN_<kind>.csv/.txt` per command, plus `prompt_log.md` |
| `other/` | saved assertions and triggers |

## Security note

This setup is not secure. The `sa` password above is public in this repo, and
`-p 1433:1433` makes SQL Server reachable from other machines on your network,
so anyone nearby who reads this README can log in. That's fine for a throwaway
class database with sample data, but don't store anything real in it.
