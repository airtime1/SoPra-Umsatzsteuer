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

## Aktuelle Integrationslogik

- `list_views.V_LIST_OUTPUT_VAT` liest Ausgangsrechnungen aus `T_INVOICE`/`T_INVOICE_ITEM` und berechnet Umsatzsteuer itembasiert. Wenn Zahlungskorrekturspalten in `T_PAYMENT_RECEIPT` vorhanden sind, liefert die View zusaetzlich negative Skonto-/Korrekturzeilen.
- `list_views.V_LIST_INPUT_VAT` liest Eingangsrechnungen aus `T_SUPPLIER_INVOICE`/`T_SUPPLIER_INVOICE_ITEM` und berechnet Vorsteuer itembasiert.
- `list_views.V_LIST_VAT_STATEMENT`, `list_views.V_LIST_VAT_STATEMENT_ITEM` und `list_views.V_LIST_VAT_USER` kapseln die eigenen Tabellen fuer die Streamlit-App.
- `stored_func.fn_get_user_security_level` liest `T_USER.SECURITYLEVEL`; die Status-Procedures pruefen erlaubte Uebergaenge ueber `T_CODE_NEXT.SECURITY_LEVEL`.

Die bekannte Sandbox und DEV koennen bei Partnergruppen-Spalten leicht auseinanderlaufen. Skripte mit dynamischer Schema-Pruefung sind deshalb bewusst idempotent und sollen nach finalen Schnittstellenentscheidungen wieder vereinfacht werden.

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
