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
| Unit | Stored Functions isoliert (`fn_check_vat_period`, `fn_calculate_vat_balance`) | SQL-Tests in `sql/` |
| Modul | Stored Procedures gegen Testdaten in Sandbox | SQL-Tests in `sql/` |
| Integration | Frontend → SP → DB → Frontend | manuell + Screenshots |
| Abnahme | Akzeptanzkriterien SPC-1..9 | manueller Durchlauf |

## Vorgehen für die Abnahme

1. Saubere Sandbox aufsetzen (`scripts/deploy_sandbox.py`).
2. Seed-Daten einspielen (`sql/99_seed/`).
3. Testfälle aus `test_cases.md` durchgehen, Ergebnis dokumentieren.
4. Abnahmekriterien mit Status `OFFEN`, `BESTANDEN` oder `FEHLER` dokumentieren.
