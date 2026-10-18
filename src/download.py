"""Download the Chinook sample database (SQLite) into data/raw/.

Source: https://github.com/lerocha/chinook-database.
The file is not committed to this repo
(see .gitignore); run this script to get it.

The script is safe to re-run: an existing file is not downloaded again.
After downloading it prints every table with its row count, which is a quick
first look at the data.
"""
import sqlite3
import sys
from pathlib import Path

import requests

URL = (
    "https://raw.githubusercontent.com/lerocha/chinook-database/master/"
    "ChinookDatabase/DataSources/Chinook_Sqlite.sqlite"
)
RAW_DIR = Path("data/raw")
DEST = RAW_DIR / "Chinook_Sqlite.sqlite"
SQLITE_MAGIC = b"SQLite format 3\x00"


def download(url: str, dest: Path) -> str:
    """Download url to dest. Returns 'downloaded' or 'skipped'."""
    if dest.exists():
        return "skipped"
    response = requests.get(url, timeout=60)
    if response.status_code != 200:
        raise RuntimeError(f"HTTP {response.status_code} for {url}")
    if not response.content.startswith(SQLITE_MAGIC):
        raise RuntimeError("Downloaded file is not a SQLite database")
    dest.write_bytes(response.content)  # written only after both checks pass
    return "downloaded"


def print_overview(db_path: Path) -> None:
    """Print each table and its number of rows."""
    with sqlite3.connect(db_path) as con:
        tables = [r[0] for r in con.execute(
            "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name")]
        print(f"\n{db_path} - {len(tables)} tables")
        for table in tables:
            rows = con.execute(f'SELECT count(*) FROM "{table}"').fetchone()[0]
            print(f"  {table:<15} {rows:>6} rows")


def main() -> int:
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    try:
        status = download(URL, DEST)
    except (requests.RequestException, RuntimeError) as err:
        print(f"Download failed: {err}")
        return 1
    print(f"{DEST.name}: {status} ({DEST.stat().st_size / 1024:.0f} KB)")
    print_overview(DEST)
    return 0


if __name__ == "__main__":
    sys.exit(main())