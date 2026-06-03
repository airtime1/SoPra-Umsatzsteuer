# SQL-Tests

Direkte SQL-Tests gegen die eigene Sandbox-DB. Jede Datei testet einen oder wenige zusammenhängende Testfälle und gibt am Ende ein `SELECT 'PASS'` oder `SELECT 'FAIL'` aus.

Konvention:
- Datei pro SPC-Kriterium oder pro Stored Object: `spc1_<beschreibung>.sql`, `sf_cal_vat_basic.sql`, …
- Vor jedem Test: Sandbox in bekannten Zustand bringen (Seed + Cleanup).
- pytest-Wrapper folgt in `tests/python/` — der pickt die SQL-Files auf und prüft die Ergebnisspalte.
