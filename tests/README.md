# Test- und Abnahmekonzept (MS5)

Hier entsteht das MS5-Konzept: Testfälle, Testdaten, Abnahmekriterien.

## Struktur

- `abnahmekriterien.md` — formale Akzeptanzkriterien (SPC-1 bis SPC-6 aus MS4, ausformuliert)
- `test_cases.md` — Testfall-Katalog (Normalfälle, Fehlerfälle, Sonderfälle)
- `sql/` — direkt ausführbare SQL-Tests gegen die Sandbox-DB (z. B. `EXEC stored_proc.SP_…`)
- `python/` (folgt) — pytest-Suite, die SQL-Tests automatisiert ausführt

## Test-Ebenen

| Ebene | Was getestet wird | Wie |
|---|---|---|
| Unit | Stored Functions isoliert (`SF_CK_VAT_PERIOD`, `SF_CAL_VAT`) | SQL-Tests in `sql/unit/` |
| Modul | Stored Procedures gegen Testdaten in Sandbox | SQL-Tests in `sql/module/` |
| Integration | Frontend → SP → DB → Frontend | manuell + Screenshots |
| Abnahme | Akzeptanzkriterien SPC-1..6 | manueller Durchlauf |

## Vorgehen für die Abnahme

1. Saubere Sandbox aufsetzen (`scripts/deploy_sandbox.py`).
2. Seed-Daten einspielen (`sql/99_seed/`).
3. Testfälle aus `test_cases.md` durchgehen, Ergebnis dokumentieren.
4. Abnahmekriterien als ✅/❌ markieren.
