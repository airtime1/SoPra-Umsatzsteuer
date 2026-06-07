# SQL-Tests

Direkte SQL-Tests gegen die eigene Sandbox-DB. Jede Datei testet einen oder wenige zusammenhängende Testfälle und gibt am Ende ein `SELECT 'PASS'` oder `SELECT 'FAIL'` aus.

Konvention:
- Datei pro SPC-Kriterium oder pro Stored Object: `spc1_<beschreibung>.sql`, `fn_calculate_vat_balance_basic.sql`, …
- Vor jedem Test: Sandbox in bekannten Zustand bringen (Seed + Cleanup).
- Ein pytest-Wrapper in `tests/python/` ist geplant, aber noch nicht angelegt.
