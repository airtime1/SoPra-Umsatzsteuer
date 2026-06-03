"""
Spielt alle SQL-Skripte aus sql/ der Reihe nach gegen die eigene Sandbox-DB ein.

Aufruf:
    python scripts/deploy_sandbox.py
    python scripts/deploy_sandbox.py --only 03_stored_func  # nur ein Ordner
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

# Wir hängen das Projektroot an den Path, damit "from app.db ..." aus scripts/ funktioniert
PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

from app.db import get_sandbox_conn  # noqa: E402

SQL_ROOT = PROJECT_ROOT / "sql"

# Reihenfolge: 00_setup, 01_tables, 02_views, 03_stored_func, 04_stored_proc,
# 05_ins_upd_views, 99_seed
DEPLOY_ORDER = [
    "00_setup",
    "01_tables",
    "02_views",
    "03_stored_func",
    "04_stored_proc",
    "05_ins_upd_views",
    "99_seed",
]


def split_batches(sql: str) -> list[str]:
    """MS SQL Server trennt Batches mit GO. pyodbc kann das nicht direkt."""
    batches = []
    current: list[str] = []
    for line in sql.splitlines():
        if line.strip().upper() == "GO":
            if current:
                batches.append("\n".join(current))
                current = []
        else:
            current.append(line)
    if current:
        batches.append("\n".join(current))
    return [b for b in batches if b.strip()]


def run_file(cur, path: Path) -> None:
    sql = path.read_text(encoding="utf-8")
    for batch in split_batches(sql):
        cur.execute(batch)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", help="Nur diesen Unterordner deployen, z. B. 03_stored_func")
    args = parser.parse_args()

    folders = DEPLOY_ORDER if not args.only else [args.only]

    with get_sandbox_conn() as conn:
        cur = conn.cursor()
        for folder in folders:
            folder_path = SQL_ROOT / folder
            if not folder_path.exists():
                continue
            files = sorted(folder_path.glob("*.sql"))
            if not files:
                print(f"[skip] {folder} (keine .sql-Dateien)")
                continue
            print(f"[deploy] {folder}")
            for f in files:
                print(f"  - {f.name}")
                try:
                    run_file(cur, f)
                except Exception as exc:
                    print(f"    FEHLER: {exc}")
                    return 1
        conn.commit()
        print("Fertig.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
