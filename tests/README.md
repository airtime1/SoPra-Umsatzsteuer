# Test- und Abnahmekonzept (MS5)

Dieser Ordner sammelt Testfall-Katalog, Abnahmekriterien und ausführbare SQL-Tests gegen die Sandbox.

## Struktur

- `abnahmekriterien.md` — formale Akzeptanzkriterien (SPC-1 bis SPC-9, ausformuliert)
- `test_cases.md` — Testfall-Katalog (Normalfälle, Fehlerfälle, Sonderfälle)
- `sql/` — direkt ausführbare SQL-Tests gegen die Sandbox-DB (z. B. `EXEC stored_proc.sp_…`)
- `python/` — geplant; pytest-Suite ist noch nicht angelegt

## Test-Ebenen

| Ebene | Was getestet wird | Wie |
|---|---|---|
| Unit | Stored Functions isoliert (`fn_G15_check_vat_period`, `fn_G15_calculate_vat_balance`) | SQL-Tests in `sql/` |
| Modul | Stored Procedures gegen Testdaten in Sandbox | SQL-Tests in `sql/` |
| Integration | Frontend → SP → DB → Frontend | manuell + Screenshots |
| Abnahme | Akzeptanzkriterien SPC-1..9 | manueller Durchlauf |

## Vorgehen für die Abnahme

1. Saubere Sandbox aufsetzen (`scripts/deploy_sandbox.py`). Der Deploy spielt `sql/99_seed/` mit ein.
2. SQL-Tests aus `tests/sql/` ausführen und prüfen, dass jede Ergebniszeile `PASS` liefert.
3. Streamlit mit `APP_DB_PROFILE=sandbox` starten und den Demo-Workflow in der UI durchgehen.
4. Testfälle aus `test_cases.md` und Abnahmekriterien dokumentieren.

## Aktuell ausführbare SQL-Tests

| Datei | Deckt ab |
|---|---|
| `tests/sql/fn_g15_calculate_vat_balance_basic.sql` | Saldo- und Typberechnung (`ZAHLLAST`, `UEBERHANG`, `NEUTRAL`) |
| `tests/sql/sp_g15_create_vat_statement_demo.sql` | Anlage einer Demo-Abrechnung, vollständige Belegübernahme, optionale Skonto-/Schnittstellenprüfung |
| `tests/sql/sp_status_workflow_roles_demo.sql` | Rollenchecks, Freigabe, Zahlung und Sperre einer bezahlten Periode |
