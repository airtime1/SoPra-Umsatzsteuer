# Testfall-Katalog

Strukturiert nach Komponente. Statuswerte: `OFFEN`, `BESTANDEN`, `FEHLER`, `TEILWEISE`.

## fn_G15_check_vat_period

Quelle: historische MS4-Tabelle „Tests SF_CK_PERIOD" + ADR-004.

| ID | Testfall | Input | Erwartet | Status |
|---|---|---|---|---|
| TC-CKP-01 | Valide neue Abrechnung | `VAT_PERIOD='2026-01'`, `CHECK_DATE='2026-02-10'` | Return `0` | OFFEN |
| TC-CKP-02 | Periode noch nicht erreicht (vor 10.) | `VAT_PERIOD='2026-01'`, `CHECK_DATE='2026-02-09'` | Return `1` | OFFEN |
| TC-CKP-03 | Bereits abgeschlossen (PAID) | `VAT_PERIOD='2026-01'` existiert mit Status `PAID`, `CHECK_DATE='2026-02-15'` | Return `2` | OFFEN |
| TC-CKP-04 | Bereits freigegeben (APPROVED, noch nicht PAID) | Existiert mit Status `APPROVED` | Return `2` | OFFEN |
| TC-CKP-05 | Bereits als DRAFT angelegt — Reset erlaubt | Existiert mit Status `DRAFT` | Return `0` | OFFEN |
| TC-CKP-06 | Ungültiges Periodenformat | `VAT_PERIOD='2026-13'` | Return `1` (kein gültiger Monat) | OFFEN |

## fn_G15_calculate_vat_balance

Quelle: historische MS4-Tabelle „Tests SF_CAL_VAT" + ADR-004 (Konvention Absolutbetrag).

| ID | Testfall | OUTPUT | INPUT | Erwartet `BALANCE` / `TYPE` | Status |
|---|---|---|---|---|---|
| TC-CAL-01 | Korrekte Zahllast | 200 | 100 | 100 / `ZAHLLAST` | BESTANDEN (`fn_g15_calculate_vat_balance_basic.sql`) |
| TC-CAL-02 | Korrekter Überhang | 100 | 200 | 100 / `UEBERHANG` | BESTANDEN (`fn_g15_calculate_vat_balance_basic.sql`) |
| TC-CAL-03 | Nur Vorsteuer | 0 | 100 | 100 / `UEBERHANG` | BESTANDEN (`fn_g15_calculate_vat_balance_basic.sql`) |
| TC-CAL-04 | Nur Umsatzsteuer | 100 | 0 | 100 / `ZAHLLAST` | BESTANDEN (`fn_g15_calculate_vat_balance_basic.sql`) |
| TC-CAL-05 | Ausgeglichen | 100 | 100 | 0 / `NEUTRAL` | BESTANDEN (`fn_g15_calculate_vat_balance_basic.sql`) |
| TC-CAL-06 | Beide null | 0 | 0 | 0 / `NEUTRAL` | BESTANDEN (`fn_g15_calculate_vat_balance_basic.sql`) |

## sp_G15_create_vat_statement

| ID | Testfall | Setup | Erwartet | Status |
|---|---|---|---|---|
| TC-SP-01 | Erste Anlage einer Periode | Leere `T_VAT_STATEMENT`, Items in T_INVOICE/T_SUPPLIER_INVOICE im Januar 2026 | Neue Kopfzeile mit `VAT_STATUS='DRAFT'`, Items + Summen passen | BESTANDEN für Demo-Periode 2026-04 (`sp_g15_create_vat_statement_demo.sql`) |
| TC-SP-02 | Re-Berechnung DRAFT | Periode bereits als DRAFT, neue Items dazugekommen | Items werden gelöscht, neu eingefügt; ID bleibt gleich | OFFEN |
| TC-SP-03 | Periode bereits APPROVED | Periode existiert APPROVED | Fehler 50002 | OFFEN |
| TC-SP-04 | Periode noch nicht abrechenbar | Aufruf vor dem 10. | Fehler 50001 | OFFEN |
| TC-SP-05 | Leere Periode | Kein Item im Monat | Kopf mit Summen 0, `VAT_TYPE='NEUTRAL'`, keine Items | OFFEN |
| TC-SP-06 | Korrektur-Item mindert USt | Reguläre Rechnung 190€ + Korrektur −6,70€ | Items beide vorhanden, Summe USt = 183,30 | TEILWEISE; Test erkennt vorhandene Zahlungskorrekturspalten oder dokumentierte Schnittstellenlücke |
| TC-SP-07 | Item außerhalb des Monats wird nicht aufgenommen | T_INVOICE-Zeile vom 31.12.2025, Periode 2026-01 | Item taucht nicht auf | OFFEN |
| TC-SP-08 | Späte Korrektur fließt in nächste offene Periode | Korrektur mit Datum 2026-02-15 bezogen auf Rechnung 2026-01 | Item landet in 2026-02, nicht in 2026-01 | OFFEN; Logik dafür muss noch in die SP |

## Status-Workflow (sp_G15_approve_vat_statement / sp_G15_pay_vat_statement / sp_G15_reject_vat_statement)

| ID | Testfall | Status |
|---|---|---|
| TC-STAT-01 | DRAFT → APPROVED durch CFO | BESTANDEN (`sp_status_workflow_roles_demo.sql`) |
| TC-STAT-02 | DRAFT → APPROVED Versuch durch Sachbearbeiter wird abgelehnt | BESTANDEN (`sp_status_workflow_roles_demo.sql`) |
| TC-STAT-03 | APPROVED → PAID durch Leitung FiBu | BESTANDEN (`sp_status_workflow_roles_demo.sql`) |
| TC-STAT-04 | APPROVED → DRAFT (Rückgabe) durch CFO | OFFEN |
| TC-STAT-05 | PAID → ? wird abgelehnt | BESTANDEN für Neuberechnung einer PAID-Periode (`sp_status_workflow_roles_demo.sql`) |
