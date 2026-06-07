# Abnahmekriterien

Basierend auf MS4 Kap. 9 (SPC-1 bis SPC-6), ergänzt um projektinterne Kriterien SPC-7 bis SPC-9.

| # | Kriterium | Definition of Done | Test-Quelle |
|---|---|---|---|
| **SPC-1** | Belege werden dem korrekten Abrechnungszeitraum zugeordnet. | Für eine Periode `YYYY-MM` enthält `T_VAT_STATEMENT_ITEM` ausschließlich Items mit `SOURCE_INVOICE_DATE BETWEEN <month_start> AND <month_end>`. Verifiziert per SQL gegen Seed. | `tests/sql/spc1_*.sql` |
| **SPC-2** | Alle steuerrelevanten Belege werden vollständig erfasst. | `COUNT(T_VAT_STATEMENT_ITEM) WHERE STATEMENT_ID = X` entspricht der Summe aus `list_views.V_LIST_OUTPUT_VAT` und `list_views.V_LIST_INPUT_VAT` für den Periodenfilter. Keine Lücke. | `tests/sql/spc2_*.sql` |
| **SPC-3** | Skonto- und Stornokorrekturen werden korrekt berücksichtigt. | Korrekturzeilen (`IS_CORRECTION=1`) sind als eigene Items vorhanden, mindern die Summe entsprechend. Zahllast vor und nach Korrektur unterscheidet sich exakt um Korrekturbetrag. | `tests/sql/spc3_*.sql` |
| **SPC-4** | Zahllast = USt − VSt (mit Vorzeichen-Konvention nach ADR-004). | Für jeden Testfall mit bekanntem `OUTPUT_VAT_TOTAL`, `INPUT_VAT_TOTAL` liefert `stored_proc.sp_create_vat_statement` exakt den erwarteten `VAT_BALANCE` und `VAT_TYPE`. | `tests/sql/spc4_*.sql` |
| **SPC-5** | Abgeschlossene Abrechnung (`PAID`) ist unveränderlich. | Versuch, eine `PAID`-Abrechnung mit `stored_proc.sp_create_vat_statement` für dieselbe Periode zu überschreiben, liefert Fehler 50002. UPDATE-Versuche auf `VAT_BALANCE` blockiert (DB-Berechtigung oder Trigger). | `tests/sql/spc5_*.sql` |
| **SPC-6** | Benutzer kann Abrechnung einsehen und nachvollziehen. | UI-Detailseite zeigt Kopfdaten + alle Items + Audit-Spuren (`CREATED_BY/AT`, `APPROVED_BY/AT`, `CLOSED_BY/AT`). Manuell verifiziert. | UI-Walkthrough |

## Zusätzliche Akzeptanzkriterien (nicht im MS4, aber sinnvoll)

| # | Kriterium | Definition of Done |
|---|---|---|
| **SPC-7** | Periode kann erst ab dem 10. des Folgemonats abgerechnet werden. | `stored_proc.sp_create_vat_statement` für aktuelle Periode wirft Fehler 50001 vor dem 10., funktioniert ab dem 10. |
| **SPC-8** | DRAFT-Abrechnungen können beliebig oft neu berechnet werden. | Erneuter Aufruf von `stored_proc.sp_create_vat_statement` für DRAFT-Periode löscht alte Items, erzeugt neue, lässt die Kopf-ID unverändert. |
| **SPC-9** | Rollen-Berechtigung wird beim Statuswechsel geprüft. | Nur CFO darf DRAFT→APPROVED, nur FiBu darf APPROVED→PAID. Technischer Rollencheck ist aktuell noch offen und muss vor Abnahme in Stored Procs oder einem abgestimmten Rollenmechanismus umgesetzt werden. |
