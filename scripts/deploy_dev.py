"""
Deploy fuer ERPDEV26S (gemeinsame Entwicklungsdatenbank).

ACHTUNG: nicht alles aus sql/ darf hier ausgefuehrt werden:
- 00_setup/ und 01_tables/ landen im dbo-Schema und brauchen den Architekt.
- Hier deployen wir nur Objekte in den uns erlaubten Schemata:
  list_views, ins_views, upd_views, stored_func, stored_proc.

Aufruf:
    python scripts/deploy_dev.py
"""

from __future__ import annotations

import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

from app.db import get_dev_conn  # noqa: E402
from scripts.deploy_sandbox import run_file  # noqa: E402

SQL_ROOT = PROJECT_ROOT / "sql"

OWN_SCHEMAS_FOLDERS = [
    "02_views",
    "03_stored_func",
    "04_stored_proc",
    "05_ins_upd_views",
]


def main() -> int:
    confirm = input(
        "Deploy auf ERPDEV26S (gemeinsame Dev-DB)! Wirklich fortfahren? [yes/N]: "
    )
    if confirm.strip().lower() != "yes":
        print("Abgebrochen.")
        return 1

    with get_dev_conn() as conn:
        cur = conn.cursor()
        for folder in OWN_SCHEMAS_FOLDERS:
            folder_path = SQL_ROOT / folder
            if not folder_path.exists():
                continue
            files = sorted(folder_path.glob("*.sql"))
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
