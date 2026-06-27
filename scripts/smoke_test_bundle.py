"""
Smoke-Test fuer das MS5-Abgabe-Bundle.

Aufruf:
    py scripts/smoke_test_bundle.py              # voller Test inkl. Sandbox-DB
    py scripts/smoke_test_bundle.py --no-db      # nur statische Pruefung, kein .env noetig

Voller Test (Default): faehrt vier Schritte gegen die eigene Sandbox aus app/db.py.
  1) Verbindung pruefen.
  2) sql/abgabe/MS5_G15_Umsatzsteuerabrechnung.sql ausfuehren (erster Lauf).
  3) Selbiges nochmal (zweiter Lauf) -> Idempotenz-Check.
  4) Objekt-Inventur: VAT-Tabellen, list_views/stored_func/stored_proc.

--no-db: nur Batch-Splitting und CREATE-Inventur. Sinnvoll vor dem Commit, wenn
keine Sandbox-Credentials greifbar sind.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

from scripts.deploy_sandbox import split_batches  # noqa: E402

BUNDLE_PATH = PROJECT_ROOT / "sql" / "abgabe" / "MS5_G15_Umsatzsteuerabrechnung.sql"

EXPECTED_COUNTS = {
    "CREATE OR ALTER VIEW":      7,
    "CREATE OR ALTER FUNCTION":  3,
    "CREATE OR ALTER PROCEDURE": 4,
    "CREATE SCHEMA":             3,
}
# Hinweis: Tabellen liegen seit ADR-008 nicht mehr im G15-Bundle,
# sondern in sql/abgabe/MS5_G15_ARCHITEKT_dbo.sql.


def step_static_check() -> bool:
    print("[statisch] Bundle parsen und CREATE-Statements zaehlen ...")
    sql = BUNDLE_PATH.read_text(encoding="utf-8")
    batches = split_batches(sql)
    joined_upper = "\n".join(batches).upper()
    print(f"      Batches gefunden: {len(batches)}")

    all_ok = True
    for keyword, expected in EXPECTED_COUNTS.items():
        actual = joined_upper.count("\n" + keyword) if "ALTER" in keyword \
                 else joined_upper.count(keyword)
        marker = "OK" if actual == expected else "ABWEICHUNG"
        print(f"      [{marker:10}] {keyword:26} {actual} (erwartet {expected})")
        if actual != expected:
            all_ok = False

    return all_ok


def step_connection() -> None:
    from app.db import get_sandbox_conn  # noqa: F401 — verzoegert wegen --no-db
    print("[1/4] Verbindung pruefen ...")
    with get_sandbox_conn() as conn:
        db_name = conn.getinfo(2)  # SQL_DATABASE_NAME
        print(f"      OK — verbunden mit {db_name}")


def step_deploy(label: str) -> None:
    from app.db import get_sandbox_conn
    print(f"[{label}] Bundle ausfuehren: {BUNDLE_PATH.relative_to(PROJECT_ROOT)}")
    sql = BUNDLE_PATH.read_text(encoding="utf-8")
    batches = split_batches(sql)
    print(f"      {len(batches)} Batches gefunden")

    with get_sandbox_conn() as conn:
        cur = conn.cursor()
        for i, batch in enumerate(batches, start=1):
            try:
                cur.execute(batch)
            except Exception as exc:
                print(f"      FEHLER in Batch {i}: {exc}")
                preview = batch.strip().splitlines()[0][:120]
                print(f"      Batch-Anfang: {preview}")
                raise
        conn.commit()
    print("      OK")


def step_inventory() -> None:
    from app.db import get_sandbox_conn
    print("[4/4] Objekt-Inventur ...")
    query = """
        SELECT s.name AS schema_name, o.name AS object_name, o.type_desc
        FROM sys.objects o
        JOIN sys.schemas s ON s.schema_id = o.schema_id
        WHERE (s.name IN ('list_views', 'stored_func', 'stored_proc')
               OR o.name LIKE 'T_VAT[_]%')
          AND o.type_desc IN (
                'USER_TABLE', 'VIEW',
                'SQL_STORED_PROCEDURE',
                'SQL_SCALAR_FUNCTION',
                'SQL_INLINE_TABLE_VALUED_FUNCTION'
          )
        ORDER BY s.name, o.name;
    """
    with get_sandbox_conn() as conn:
        rows = conn.cursor().execute(query).fetchall()

    by_schema: dict[str, list[tuple[str, str]]] = {}
    for schema, name, type_desc in rows:
        by_schema.setdefault(schema, []).append((name, type_desc))

    expected = {
        "dbo": {"T_VAT_STATEMENT", "T_VAT_STATEMENT_ITEM"},
        "list_views": {
            "LOV_VAT_STATUS", "V_LIST_G15_OUTPUT_VAT", "V_LIST_G15_VAT_SKONTO",
            "V_LIST_G15_INPUT_VAT", "V_LIST_G15_VAT_STATEMENT",
            "V_LIST_G15_VAT_STATEMENT_ITEM", "V_LIST_G15_VAT_USER",
        },
        "stored_func": {
            "fn_G15_check_vat_period", "fn_G15_calculate_vat_balance",
        },
        "stored_proc": {
            "sp_G15_create_vat_statement", "sp_G15_approve_vat_statement",
            "sp_G15_pay_vat_statement", "sp_G15_reject_vat_statement",
        },
    }

    all_ok = True
    for schema, names in expected.items():
        found = {n for n, _ in by_schema.get(schema, [])}
        missing = names - found
        extra = found - names if schema != "dbo" else set()
        status = "OK" if not missing else "FEHLT"
        print(f"      [{status}] {schema}: {len(found & names)}/{len(names)}")
        if missing:
            all_ok = False
            print(f"             fehlen: {sorted(missing)}")
        if extra:
            print(f"             zusaetzlich: {sorted(extra)}")

    if all_ok:
        print("      OK — alle erwarteten Objekte vorhanden.")
    else:
        print("      WARNUNG — Objekte fehlen. Bitte Output oben pruefen.")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--no-db",
        action="store_true",
        help="Nur statische Pruefung (kein .env / keine DB-Verbindung noetig).",
    )
    args = parser.parse_args()

    if not BUNDLE_PATH.exists():
        print(f"FEHLER: Bundle nicht gefunden: {BUNDLE_PATH}")
        return 1

    try:
        if args.no_db:
            ok = step_static_check()
            print("\nFertig (statisch)." if ok else "\nFertig — mit Abweichungen.")
            return 0 if ok else 1

        step_static_check()
        step_connection()
        step_deploy("2/4")  # erster Lauf
        step_deploy("3/4")  # zweiter Lauf — Idempotenz
        step_inventory()
    except Exception as exc:
        print(f"\nAbbruch: {exc}")
        return 1

    print("\nFertig.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
