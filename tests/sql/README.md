# SQL-Tests

Direkte SQL-Tests gegen die eigene Sandbox-DB. Jede Datei testet einen oder wenige zusammenhängende Testfälle und gibt am Ende ein `SELECT 'PASS'` oder `SELECT 'FAIL'` aus.

Konvention:
- Datei pro SPC-Kriterium oder pro Stored Object: `spc1_<beschreibung>.sql`, `fn_g15_calculate_vat_balance_basic.sql`, …
- Vor jedem Test: Sandbox in bekannten Zustand bringen (Seed + Cleanup).
- Ein pytest-Wrapper in `tests/python/` ist geplant, aber noch nicht angelegt.

Aktuelle Dateien:

| Datei | Erwartung |
|---|---|
| `fn_g15_calculate_vat_balance_basic.sql` | Sechs Ergebniszeilen, alle `PASS` |
| `sp_g15_create_vat_statement_demo.sql` | Drei Ergebniszeilen, alle `PASS` |
| `sp_status_workflow_roles_demo.sql` | Fuenf Ergebniszeilen, alle `PASS` |
