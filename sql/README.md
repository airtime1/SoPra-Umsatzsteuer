# SQL-Skripte

Reihenfolge der Ausführung beim Aufbau einer leeren Sandbox:

1. `00_setup/` — Stammdaten (`T_CODE`, `T_CODE_NEXT`). **An Architekt liefern** für `ERPDEV26S`. Auf eigener Sandbox selbst ausführen.
2. `01_tables/` — Tabellen und idempotente Constraint-Upgrades. **An Architekt liefern** für `ERPDEV26S`.
3. `02_views/` — Lese-Views (`list_views.*`).
4. `03_stored_func/` — Stored Functions (`stored_func.fn_*`).
5. `04_stored_proc/` — Stored Procedures (`stored_proc.sp_*`).
6. `05_ins_upd_views/` — Schreib-Wrapper-Views (`ins_views.*`, `upd_views.*`) — wenn Architekt sie bestätigt.
7. `99_seed/` — Testdaten für die Sandbox.

`99_devdb_kopie/` enthält die Referenz-DB-Kopie, die wir von der HdM bekommen — nicht selbst pflegen, nur als Lookup.

`abgabe/` enthält gebündelte Einzel-SQL-Dateien für die MS5-Abgabe an zwei Ziele:

- `abgabe/MS5_G15_Umsatzsteuerabrechnung.sql` — G15-Anteil: Schemas (`list_views`, `stored_func`, `stored_proc`), Views, Funcs, Procs. Idempotent, mehrfach ausführbar.
- `abgabe/MS5_G15_ARCHITEKT_dbo.sql` — Architekten-Anteil: T_CODE-Einträge VAT_STATUS und Tabellen `T_VAT_STATEMENT` / `T_VAT_STATEMENT_ITEM`. Wird vom Datenbank-Architekten gegen `ERPDEV26S` ausgeführt, da `dbo` für uns gesperrt ist.

Die Trennung in zwei Dateien bildet die Berechtigungs-Realität ab: G15 darf nur in eigene Schemata schreiben, der Architekt hält `dbo` exklusiv.

## Aktuelle Integrationslogik

Gemäß ADR-008 berechnet G15 keine Steuerbeträge. Wir konsumieren TAX_AMOUNT direkt aus Partner-Lese-Views:

- `list_views.V_LIST_OUTPUT_VAT` — eine Quelle: G7 (`V_LIST_G07_INVOICE` über `T_INVOICE`); G9 (Bar Rosenberg) und G10 (Bar Freiburg) laufen über dieselbe Tabelle mit (Beschluss 2026-06-16). Aktuell liefert G7s View nur Fernabsatz, B2C-Erweiterung ist G7s Bring-Schuld.
- `list_views.V_LIST_VAT_SKONTO` — finaler Steuerbetrag je Rechnung aus G8; überschreibt in `sp_create_vat_statement` den Rechnungsbetrag bei Skonto (ADR-010, aktuell Stub).
- `list_views.V_LIST_INPUT_VAT` — G4 (Wareneingänge, Stub).
- `list_views.V_LIST_VAT_STATEMENT`, `list_views.V_LIST_VAT_STATEMENT_ITEM` und `list_views.V_LIST_VAT_USER` kapseln die eigenen Tabellen für die Streamlit-App.
- `stored_func.fn_get_user_security_level` liest `T_USER.SECURITYLEVEL`; die Status-Procedures prüfen erlaubte Übergänge über `T_CODE_NEXT.SECURITY_LEVEL`.

Stubs liefern Spalten mit korrekter Signatur, aber 0 Zeilen (`WHERE 1 = 0`). Aktivierung = auskommentierten Block in der View durch echten SELECT austauschen, siehe Kommentare in den View-Dateien.

## Namenskonventionen

**Verbindlich: HdM-Vorgabe** (siehe `docs/namenskonventionen/INDEX.md` und `Lerneinheit_7_Datenbankentwicklung.docx`).

Kurz-Cheatsheet:

| Objekt | Pattern | Beispiel |
|---|---|---|
| Tabelle | `dbo.T_<NAME>` UPPER | `dbo.T_VAT_STATEMENT` |
| Tabellen-Spalte | UPPER_SNAKE | `VAT_STATUS`, `SOURCE_INVOICE_DATE` |
| LOV-View | `list_views.LOV_<NAME>` | `list_views.LOV_VAT_STATUS` |
| List-View | `list_views.V_LIST_<NAME>` | `list_views.V_LIST_OUTPUT_VAT` |
| Insert-View | `ins_views.V_INS_<NAME>` | (bei Bedarf) |
| Update-View | `upd_views.V_UPD_<NAME>` | (bei Bedarf) |
| Stored Function | `stored_func.fn_<purpose>_<entity>` klein | `stored_func.fn_calculate_vat_balance` |
| Stored Procedure | `stored_proc.sp_<action>_<entity>` klein | `stored_proc.sp_create_vat_statement` |
| Parameter | `@<name>` klein, snake_case | `@vat_period`, `@created_by` |
| Constraints | `CHK_`/`FK_`/`PK_/UQ_` + Tabelle + Spalte UPPER | `CHK_VAT_STATEMENT_STATUS` |
