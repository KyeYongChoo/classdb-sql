"""Tiny T-SQL shell for a database class (SQL Server via pyodbc).

On startup every input/*.csv becomes a table in database CLASSDB (file name =
table name). Every batch and its output is written to output/NNN_<kind>.txt
(or .csv for result sets) and appended to output/prompt_log.md. Previous
output is wiped at startup; pass --keep to append to it instead.

Batches end with a line containing only GO (like sqlcmd/SSMS). A single-line
statement ending in ';' also runs immediately.

SQL Server has no CREATE ASSERTION, so this shell adds it:
  CREATE ASSERTION name CHECK (condition);
  DROP ASSERTION name;
Each assertion becomes an AFTER INSERT/UPDATE/DELETE trigger named
assert_<name>__<table> on every table the condition mentions. The trigger
rolls the transaction back when the condition is false.

Saved definitions (replayed on next startup, since tables are reloaded):
  other/assertions.json   {name: condition}
  other/triggers.sql      user triggers, batches separated by GO

Connection settings come from environment variables:
  MSSQL_SERVER (default localhost,1433)  MSSQL_USER (sa)  MSSQL_PASSWORD
  MSSQL_DRIVER (default ODBC Driver 18 for SQL Server)
"""
import csv
import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path

import pyodbc

DB_NAME = "CLASSDB"
ROOT = Path(__file__).parent
INPUT, OUTPUT, OTHER = ROOT / "input", ROOT / "output", ROOT / "other"
ASSERTIONS_FILE = OTHER / "assertions.json"
TRIGGERS_FILE = OTHER / "triggers.sql"
PROMPT_LOG = OUTPUT / "prompt_log.md"

CREATE_ASSERT = re.compile(
    r"^\s*CREATE\s+ASSERTION\s+(\w+)\s+CHECK\s*\((.*)\)\s*;?\s*$", re.I | re.S)
DROP_ASSERT = re.compile(r"^\s*DROP\s+ASSERTION\s+(\w+)\s*;?\s*$", re.I)
GO_LINE = re.compile(r"^\s*GO\s*$", re.I)
# batches that normally hold several statements: end these with GO, not ";"
MULTI_STATEMENT = r"(CREATE|ALTER)\s+(TRIGGER|PROC|PROCEDURE|FUNCTION|VIEW)\b|(DECLARE|BEGIN|IF|WHILE)\b"


def connect(database=None, autocommit=False):
    parts = [
        f"DRIVER={{{os.environ.get('MSSQL_DRIVER', 'ODBC Driver 18 for SQL Server')}}}",
        f"SERVER={os.environ.get('MSSQL_SERVER', 'localhost,1433')}",
        f"UID={os.environ.get('MSSQL_USER', 'sa')}",
        f"PWD={os.environ.get('MSSQL_PASSWORD', '')}",
        "TrustServerCertificate=yes",
    ]
    if database:
        parts.append(f"DATABASE={database}")
    return pyodbc.connect(";".join(parts), autocommit=autocommit)


def infer_type(values):
    for typ, cast in (("BIGINT", int), ("FLOAT", float)):
        try:
            for v in values:
                if v != "":
                    cast(v)
            return typ
        except ValueError:
            continue
    return "NVARCHAR(255)"


def load_csvs(cur):
    loaded = []
    for path in sorted(INPUT.glob("*.csv")):
        with path.open(newline="", encoding="utf-8-sig") as f:
            rows = list(csv.reader(f))
        if not rows:
            continue
        header, body = rows[0], rows[1:]
        types = [infer_type([r[i] for r in body if i < len(r)]) for i in range(len(header))]
        cols = ", ".join(f"[{h}] {t}" for h, t in zip(header, types))
        cur.execute(f"CREATE TABLE [{path.stem}] ({cols})")
        if body:
            marks = ", ".join("?" * len(header))
            cur.executemany(
                f"INSERT INTO [{path.stem}] VALUES ({marks})",
                [[(v if v != "" else None) for v in r] for r in body])
        loaded.append(f"{path.stem} ({len(body)} rows)")
    return loaded


def referenced_tables(cur, condition):
    """Tables from the database whose name appears as a word in the condition."""
    names = [r[0] for r in cur.execute(
        "SELECT name FROM sys.tables WHERE name NOT LIKE '[_]%'").fetchall()]
    return [n for n in names
            if re.search(rf"(?<![\w@]){re.escape(n)}(?!\w)", condition, re.I)]


def assertion_trigger_sql(name, table, condition):
    return (
        f"CREATE TRIGGER [assert_{name}__{table}] ON [{table}] "
        f"AFTER INSERT, UPDATE, DELETE AS\n"
        f"BEGIN\n"
        f"  IF NOT ({condition})\n"
        f"  BEGIN\n"
        f"    ROLLBACK TRANSACTION;\n"
        f"    THROW 50001, 'Assertion {name} violated', 1;\n"
        f"  END\n"
        f"END")


def format_table(cols, rows):
    cells = [[("NULL" if v is None else str(v)) for v in r] for r in rows]
    widths = [max([len(c)] + [len(r[i]) for r in cells]) for i, c in enumerate(cols)]
    line = lambda r: " | ".join(v.ljust(w) for v, w in zip(r, widths))
    return "\n".join([line(cols), "-+-".join("-" * w for w in widths)]
                     + [line(r) for r in cells] + [f"({len(rows)} rows)"])


def split_batches(text):
    """Split script text on GO lines; yields non-empty batches."""
    batch = []
    for line in text.splitlines():
        if GO_LINE.match(line):
            if "".join(batch).strip():
                yield "\n".join(batch)
            batch = []
        else:
            batch.append(line)
    if "".join(batch).strip():
        yield "\n".join(batch)


class Shell:
    def __init__(self, keep_output=False):
        for d in (INPUT, OUTPUT, OTHER):
            d.mkdir(exist_ok=True)
        if not keep_output:  # only files this shell writes; anything else stays
            for f in [*OUTPUT.glob("[0-9][0-9][0-9]_*"), PROMPT_LOG]:
                f.unlink(missing_ok=True)
        admin = connect(autocommit=True)
        admin.execute(f"IF DB_ID('{DB_NAME}') IS NOT NULL BEGIN "
                      f"ALTER DATABASE {DB_NAME} SET SINGLE_USER WITH ROLLBACK IMMEDIATE; "
                      f"DROP DATABASE {DB_NAME}; END")
        admin.execute(f"CREATE DATABASE {DB_NAME}")
        admin.close()
        self.db = connect(DB_NAME)
        self.cur = self.db.cursor()
        self.buf = []
        self.n = len(list(OUTPUT.glob("[0-9]*_*")))
        loaded = load_csvs(self.cur)
        self.db.commit()
        self.assertions = {}
        # Saved definitions whose tables a script creates later can't be built
        # yet; keep them saved so the script (or the next startup) recreates them.
        if ASSERTIONS_FILE.exists():
            for name, cond in json.loads(ASSERTIONS_FILE.read_text(encoding="utf-8")).items():
                try:
                    self.create_assertion(name, cond)
                except pyodbc.Error:
                    self.db.rollback()
                    self.assertions[name] = cond
        if TRIGGERS_FILE.exists():
            for b in split_batches(TRIGGERS_FILE.read_text(encoding="utf-8")):
                try:
                    self.cur.execute(b)
                    self.db.commit()
                except pyodbc.Error:
                    self.db.rollback()
        self.record("startup", "(startup)",
                    "Loaded: " + (", ".join(loaded) or "no CSVs found in input/"))

    # ---- logging -------------------------------------------------------
    def record(self, kind, command, text, rows=None):
        """Print, write output/NNN_kind.(txt|csv), and append to the prompt log."""
        print(text)
        self.n += 1
        stem = OUTPUT / f"{self.n:03d}_{kind}"
        if rows is not None:
            with stem.with_suffix(".csv").open("w", newline="", encoding="utf-8") as f:
                w = csv.writer(f)
                w.writerow(rows[0])
                w.writerows(rows[1])
        else:
            stem.with_suffix(".txt").write_text(text + "\n", encoding="utf-8")
        with PROMPT_LOG.open("a", encoding="utf-8") as f:
            f.write(f"## {self.n:03d} · {datetime.now():%Y-%m-%d %H:%M:%S}\n\n"
                    f"**Command**\n```sql\n{command.strip()}\n```\n\n"
                    f"**Output**\n```\n{text}\n```\n\n")

    # ---- definitions ---------------------------------------------------
    def save_definitions(self):
        ASSERTIONS_FILE.write_text(json.dumps(self.assertions, indent=2), encoding="utf-8")
        mods = self.cur.execute(
            "SELECT m.definition FROM sys.triggers t "
            "JOIN sys.sql_modules m ON m.object_id = t.object_id "
            "WHERE t.name NOT LIKE 'assert[_]%'").fetchall()
        TRIGGERS_FILE.write_text("\nGO\n".join(m[0].strip() for m in mods) + "\nGO\n",
                                 encoding="utf-8")

    def create_assertion(self, name, cond):
        """Create the enforcing triggers; raises pyodbc.Error if cond is invalid/violated."""
        tables = referenced_tables(self.cur, cond)
        if not tables:
            raise pyodbc.Error("assertion mentions no known table")
        ok = self.cur.execute(f"SELECT CASE WHEN ({cond}) THEN 1 ELSE 0 END").fetchone()[0]
        if not ok:
            raise pyodbc.Error(f"assertion {name} already fails on current data")
        for t in tables:
            self.cur.execute(assertion_trigger_sql(name, t, cond))
        self.db.commit()
        self.assertions[name] = cond

    def drop_assertion(self, name):
        trigs = self.cur.execute(
            "SELECT name FROM sys.triggers WHERE name LIKE ? ESCAPE '\\'",
            f"assert\\_{name}\\_\\_%").fetchall()
        for (t,) in trigs:
            self.cur.execute(f"DROP TRIGGER [{t}]")
        self.db.commit()
        self.assertions.pop(name, None)

    # ---- running -------------------------------------------------------
    def run(self, batch):
        try:
            if m := CREATE_ASSERT.match(batch):
                self.create_assertion(m.group(1), m.group(2))
                self.save_definitions()
                return self.record("assertion", batch, f"Assertion {m.group(1)} created")
            if m := DROP_ASSERT.match(batch):
                if m.group(1) not in self.assertions:
                    raise pyodbc.Error(f"no assertion {m.group(1)}")
                self.drop_assertion(m.group(1))
                self.save_definitions()
                return self.record("assertion", batch, f"Assertion {m.group(1)} dropped")

            self.cur.execute(batch)
            parts, rows_out, first = [], None, True
            while True:
                if self.cur.description:
                    cols = [d[0] for d in self.cur.description]
                    rows = [tuple(r) for r in self.cur.fetchall()]
                    parts.append(format_table(cols, rows))
                    if first:
                        rows_out = (cols, rows)
                    first = False
                elif self.cur.rowcount >= 0:
                    parts.append(f"({self.cur.rowcount} rows affected)")
                if not self.cur.nextset():
                    break
            # PRINT output and low-severity messages arrive here
            parts += [m[1].split("]")[-1].strip() for m in self.cur.messages or []]
            self.db.commit()
            if re.search(r"\b(CREATE|ALTER|DROP)\s+TRIGGER\b", batch, re.I):
                self.save_definitions()
            text = "\n".join(parts) or "Commands completed successfully."
            kind = "query" if rows_out else "write"
            self.record(kind, batch, text, rows=rows_out if len(parts) == 1 else None)
        except pyodbc.Error as e:
            try:
                self.db.rollback()
            except pyodbc.Error:
                pass
            msg = str(e.args[-1]) if e.args else str(e)
            self.record("error", batch, "Error: " + re.sub(r"^(\[[^\]]*\])+", "", msg).strip())

    def feed(self, lines):
        """Run batches from an iterable of lines.

        A batch ends at a GO line, or at a line ending in ';' unless the batch
        needs several statements (triggers, procedures, DECLARE/BEGIN/IF...);
        those need GO. Comment-only batches are skipped.
        """
        self.buf = []
        for line in lines:
            if not self.buf and line.strip().lower() in ("exit", "quit"):
                break
            if GO_LINE.match(line):
                self.flush()
                continue
            self.buf.append(line)
            code = [l.strip() for l in self.buf if l.strip() and not l.strip().startswith("--")]
            if (code and code[-1].endswith(";")
                    and not re.match(MULTI_STATEMENT, " ".join(code), re.I)):
                self.flush()
        self.flush()

    def flush(self):
        batch = "\n".join(self.buf)
        self.buf = []
        if any(l.strip() and not l.strip().startswith("--") for l in batch.splitlines()):
            self.run(batch)


def stdin_lines(shell):
    while True:
        try:
            yield input("...> " if shell.buf else "sql> ")
        except EOFError:
            return


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if a != "--keep"]
    shell = Shell(keep_output="--keep" in sys.argv)
    if args:  # python sqlshell.py script.sql
        shell.feed(Path(args[0]).read_text(encoding="utf-8").splitlines())
    else:
        shell.feed(stdin_lines(shell))
