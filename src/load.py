"""Load the Chinook SQLite file into DuckDB (data/chinook.duckdb).

Raw layer: every source table is copied 1:1 into a table named raw_<table>.
No cleaning here; casting and cleaning happen in sql/01_staging.sql.

"""
import sqlite3
import sys
from pathlib import Path

import duckdb
import pandas as pd

SRC = Path("data/raw/Chinook_Sqlite.sqlite")
DB_PATH = Path("data/chinook.duckdb")


def main() -> int:
    if not SRC.exists():
        print(f"{SRC} not found. Run: make download")
        return 1
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)

    src = sqlite3.connect(SRC)
    dst = duckdb.connect(str(DB_PATH))
    try:
        tables = [r[0] for r in src.execute(
            "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name")]
        for table in tables:
            df = pd.read_sql_query(f'SELECT * FROM "{table}"', src)
            df = df.convert_dtypes()

            dst.register("df", df)
            dst.execute(f'CREATE OR REPLACE TABLE raw_{table.lower()} AS SELECT * FROM df')
            dst.unregister("df")

            n = dst.execute(f"SELECT count(*) FROM raw_{table.lower()}").fetchone()[0]
            print(f"raw_{table.lower():<15} {n:>6} rows")
    finally:
        src.close()
        dst.close()
    print(f"\nWrote {DB_PATH}")
    return 0


if __name__ == "__main__":
    sys.exit(main())