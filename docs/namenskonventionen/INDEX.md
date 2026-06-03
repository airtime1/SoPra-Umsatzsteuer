# HdM-Namenskonventionen — Zusammenfassung

Quelle: `Lerneinheit_7_Datenbankentwicklung.docx` (Prof. Lehmann, SoPra SoSe 2026) — Original liegt im selben Ordner.

Diese Datei ist die für uns relevante Kurzfassung. Bei Konflikt zwischen dieser Seite und dem Original gilt das Original.

## Architekturprinzip

Zugriff auf Daten **ausschließlich** über Views, Stored Functions und Stored Procedures. Geschäftslogik nah an die Daten bringen.

## Groß-/Kleinschreibung

| Element | Konvention |
|---|---|
| Tabellennamen | `ALLES_GROSS` |
| Tabellen-Spaltennamen | `ALLES_GROSS` |
| Stored Procedures | `klein` (snake_case) |
| Stored Functions | `klein` (snake_case) |
| Parameter | `klein` mit `_`, sprechend, z. B. `@invoice_id`, `@customer_id` |
| View-Namen | `ALLES_GROSS` (mit Präfix) |
| View-Spaltennamen | `GROSSkleinschreibung` (CamelCase), wenn man umbenennt; sonst Original-Tabellenspalte durchreichen |

Trennzeichen: Underscore `_`. Kein Bindestrich.

Sprache einheitlich, nicht gemischt (in unserem Projekt: Englisch).

## Präfixe

| Objekttyp | Präfix | Schema |
|---|---|---|
| Tabelle | `T_` | `dbo` (nur Architekt) |
| Stored Procedure | `sp_` | `stored_proc` |
| Stored Function | `fn_` | `stored_func` |
| View zum Anzeigen (Liste) | `V_LIST_` | `list_views` |
| View für Werteliste (Dropdown) | `LOV_` | `list_views` |
| View zum Einfügen | `V_INS_` | `ins_views` |
| View zum Ändern | `V_UPD_` | `upd_views` |

## Formate

**Stored Procedure:** `<SCHEMA>.sp_<ACTION>_<ENTITY>[_<DETAIL>]`
Beispiele aus der Dev-DB:
- `stored_proc.sp_create_salesorder_from_offer`
- `stored_proc.sp_apply_receipt_to_invoice`
- `stored_proc.sp_close_delivery_if_complete`

**Stored Function:** `<SCHEMA>.fn_<PURPOSE>_<ENTITY>`
Beispiele:
- `stored_func.fn_calculate_total_amount`
- `stored_func.fn_get_customer_outstanding_balance`
- `stored_func.fn_is_invoice_fully_payed`

**Views:** `<PRÄFIX>_<ENTITY>[_<DETAIL>]`
Beispiele aus der Dev-DB:
- `LOV_STATUS_ORDER`, `LOV_PAYMENT_METHOD`, `LOV_STATUS_FOLGE`
- `V_LIST_BIKE_ORDERS_BOM`, `V_LIST_CHANGE_REQUESTS`
- `V_INS_INVOICE_B2C`, `V_INS_CHANGE_REQUEST`
- `V_UPD_CHANGE_REQUEST`

## Mapping unserer Objekte

| MS4 sagte | HdM-konform |
|---|---|
| `SF_CK_VAT_PERIOD` | `stored_func.fn_check_vat_period` |
| `SF_CAL_VAT` | `stored_func.fn_calculate_vat_balance` |
| `SP_CREATE_VAT_STATEMENT` | `stored_proc.sp_create_vat_statement` |
| `LOV_VAT_STATUS` (lov_views) | `list_views.LOV_VAT_STATUS` |
| `OUTPUT_VAT_TOTAL` | `list_views.V_LIST_OUTPUT_VAT` |
| `INPUT_VAT_TOTAL` | `list_views.V_LIST_INPUT_VAT` |
| `T_VAT_STATEMENT` | `dbo.T_VAT_STATEMENT` (unverändert) |
| `T_VAT_STATEMENT_ITEM` | `dbo.T_VAT_STATEMENT_ITEM` (unverändert) |
| Spalte `VAT_STATUS` | bleibt `VAT_STATUS` (Tabellenspalte = UPPER_CASE) |

Status-Workflow-Procs (ergänzt):
- `stored_proc.sp_approve_vat_statement` — DRAFT → APPROVED
- `stored_proc.sp_pay_vat_statement` — APPROVED → PAID
- `stored_proc.sp_reject_vat_statement` — APPROVED → DRAFT

## Wichtig zur Beobachtung in der Dev-DB

Die existierenden Views in `dbo` verwenden **nicht** durchgängig CamelCase für Spaltennamen — z. B. `LOV_STATUS_FOLGE` exponiert `STATUS_IST`/`STATUS_NEXT` (UPPER_CASE). Wir halten uns an die Doku-Vorgabe (CamelCase wenn umbenannt), reichen aber Original-UPPER-Spalten durch, wo keine Umbenennung sinnvoll ist.
