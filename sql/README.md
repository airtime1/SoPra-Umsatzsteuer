# SQL-Skripte

Reihenfolge der Ausführung beim Aufbau einer leeren Sandbox:

1. `00_setup/` — Stammdaten (`T_CODE`, `T_CODE_NEXT`). **An Architekt liefern** für `ERPDEV26S`. Auf eigener Sandbox selbst ausführen.
2. `01_tables/` — Tabellen. **An Architekt liefern** für `ERPDEV26S`.
3. `02_views/` — Lese-Views (`list_views.*`).
4. `03_stored_func/` — Stored Functions (`stored_func.SF_*`).
5. `04_stored_proc/` — Stored Procedures (`stored_proc.SP_*`).
6. `05_ins_upd_views/` — Schreib-Wrapper-Views (`ins_views.*`, `upd_views.*`) — wenn Architekt sie bestätigt.
7. `99_seed/` — Testdaten für die Sandbox.

`99_devdb_kopie/` enthält die Referenz-DB-Kopie, die wir von der HdM bekommen — nicht selbst pflegen, nur als Lookup.

## Namenskonventionen (eigene Festlegungen, ergänzend zur HdM-Vorgabe in `docs/namenskonventionen/`)

- Tabellen: `T_<MODUL>_<NAME>` (z. B. `T_VAT_STATEMENT`)
- Views: `<SCHEMA>.<KATEGORIE>_<MODUL>_<NAME>` (z. B. `list_views.OUTPUT_VAT_TOTAL`)
- Stored Functions: `stored_func.SF_<VERB>_<NAME>` (z. B. `SF_CK_VAT_PERIOD`)
- Stored Procedures: `stored_proc.SP_<VERB>_<NAME>` (z. B. `SP_CREATE_VAT_STATEMENT`)
- Spalten: `SNAKE_CASE`, sprechende englische Namen
- Constraints: `<TYP>_<TABELLE>_<SPALTE>` (z. B. `CHK_VAT_STATEMENT_STATUS`, `FK_VAT_ITEM_STATEMENT`)
