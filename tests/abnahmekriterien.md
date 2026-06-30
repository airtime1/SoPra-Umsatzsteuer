# Abnahmekriterien

Basierend auf MS4 Kap. 9 (SPC-1 bis SPC-6), ergänzt um projektinterne Kriterien SPC-7 bis SPC-9.

| # | Kriterium | Definition of Done | Test-Quelle |
|---|---|---|---|
| **SPC-1** | Belege werden dem korrekten Abrechnungszeitraum zugeordnet. | Für eine Periode `YYYY-MM` enthält `T_VAT_STATEMENT_ITEM` ausschließlich Items mit `SOURCE_INVOICE_DATE BETWEEN <month_start> AND <month_end>`. Verifiziert per SQL gegen Seed. | `tests/sql/spc1_*.sql` |
| **SPC-2** | Alle steuerrelevanten Belege werden vollständig erfasst. | `COUNT(T_VAT_STATEMENT_ITEM) WHERE STATEMENT_ID = X` entspricht der Summe aus `list_views.V_LIST_G15_OUTPUT_VAT` und `list_views.V_LIST_G15_INPUT_VAT` für den Periodenfilter. Keine Lücke. | `tests/sql/spc2_*.sql` |
| **SPC-3** | Skonto- und Stornokorrekturen werden korrekt berücksichtigt. | Korrekturzeilen (`IS_CORRECTION=1`) sind als eigene Items vorhanden, mindern die Summe entsprechend. Zahllast vor und nach Korrektur unterscheidet sich exakt um Korrekturbetrag. | `tests/sql/spc3_*.sql` |
| **SPC-4** | Zahllast = USt − VSt (mit Vorzeichen-Konvention nach ADR-004). | Für jeden Testfall mit bekanntem `OUTPUT_VAT_TOTAL`, `INPUT_VAT_TOTAL` liefert `stored_proc.sp_G15_create_vat_statement` exakt den erwarteten `VAT_BALANCE` und `VAT_TYPE`. | `tests/sql/spc4_*.sql` |
| **SPC-5** | Abgeschlossene Abrechnung (`PAID`) ist unveränderlich. | Versuch, eine `PAID`-Abrechnung mit `stored_proc.sp_G15_create_vat_statement` für dieselbe Periode zu überschreiben, liefert Fehler 50002. Direkte Tabellen-Updates sind nicht Teil des Streamlit-Flows und müssen über DB-Rechte/Architekt geregelt werden. | `tests/sql/sp_status_workflow_roles_demo.sql` |
| **SPC-6** | Benutzer kann Abrechnung einsehen und nachvollziehen. | UI-Detailseite zeigt Kopfdaten + alle Items + Audit-Spuren (`CREATED_BY/AT`, `APPROVED_BY/AT`, `CLOSED_BY/AT`). Manuell verifiziert. | UI-Walkthrough |

## Zusätzliche Akzeptanzkriterien (nicht im MS4, aber sinnvoll)

| # | Kriterium | Definition of Done |
|---|---|---|
| **SPC-7** | Periode kann erst ab dem 10. des Folgemonats abgerechnet werden. | `stored_proc.sp_G15_create_vat_statement` für aktuelle Periode wirft Fehler 50001 vor dem 10., funktioniert ab dem 10. |
| **SPC-8** | DRAFT-Abrechnungen können beliebig oft neu berechnet werden. | Erneuter Aufruf von `stored_proc.sp_G15_create_vat_statement` für DRAFT-Periode löscht alte Items, erzeugt neue, lässt die Kopf-ID unverändert. |
| **SPC-9** | Rollen-Berechtigung wird beim Statuswechsel geprüft. | Security-Level wirken hierarchisch: Level 1 darf Level-1-Aktionen, Level 2 zusätzlich Level-2-Aktionen, Level 3 zusätzlich Level-3-Aktionen. Der technische Rollencheck liegt in den Stored Procedures und liest `T_USER.SECURITYLEVEL` sowie den Mindest-Level aus `T_CODE_NEXT.SECURITY_LEVEL`. |

## Aktueller Teststand

| Bereich | Stand |
|---|---|
| Saldo-/Typberechnung | BESTANDEN in Sandbox mit `fn_g15_calculate_vat_balance_basic.sql` |
| Demo-Anlage 2026-04 | BESTANDEN in Sandbox mit `sp_g15_create_vat_statement_demo.sql` |
| Status/Rollen/PAID-Sperre | BESTANDEN in Sandbox mit `sp_status_workflow_roles_demo.sql` |
| UI-Walkthrough | Manuell geprüft: Startseite, Übersicht, neue Abrechnung, Detailseite laden gegen Sandbox |
| Noch offen | Explizite SQL-Tests für `fn_G15_check_vat_period`, Rückgabe `APPROVED -> DRAFT`, echte Partnerdaten-Szenarien für Storno/Teilstorno |
