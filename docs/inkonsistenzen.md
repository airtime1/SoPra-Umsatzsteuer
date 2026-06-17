# Inkonsistenzen MS3 (Fachkonzept) ↔ MS4 (Systemkonzept)

Beim Übergang vom Fach- ins Systemkonzept sind mehrere Konflikte und Unklarheiten entstanden. Hier dokumentiert mit jeweils gewählter Auflösung. Detaillierte Begründungen in `docs/entscheidungen/`.

| # | Punkt | MS3 sagt | MS4 sagt | Auflösung | ADR |
|---|---|---|---|---|---|
| 1 | Status-Modell | 4 Status DE: ENTWURF → IN PRÜFUNG → FREIGEGEBEN → ABGESCHLOSSEN | 3 Status EN: DRAFT → APPROVED → PAID | **MS4: 3 Status EN**, Rückgabe APPROVED → DRAFT als Korrekturpfad | [001](entscheidungen/001-status-modell.md) |
| 2 | Rollen 2 ↔ 3 | Stufe 2 = Buchhaltung prüft, Stufe 3 = CFO überweist | Stufe 2 = Leitung FiBu (PAID), Stufe 3 = CFO (APPROVED) | **MS4-Reihenfolge**: Sachbearbeiter → CFO (freigeben) → FiBu (auszahlen) | [002](entscheidungen/002-rollen.md) |
| 3 | Statusspalte | `VAT_STATUS` | im CREATE TABLE `STATUS`, in Beschreibung `VAT_STATUS` | **`VAT_STATUS`** | [003](entscheidungen/003-namen.md) |
| 4 | Belegdatum-Spalte | nicht detailliert | in Beschreibung `SOURCE_INVOICE_DATE`, im CREATE TABLE `INVOICE_DATE` | **`SOURCE_INVOICE_DATE`** | [003](entscheidungen/003-namen.md) |
| 5 | Vorzeichen Saldo | Beispiel zeigt `-95` als Überhang (negativ) | SF_CAL_VAT: Überhang = negativ, aber Testcase zeigt `VAT_BALANCE = 100` (positiv) + `TYPE = Überhang` | **`VAT_BALANCE` immer ≥0 (Absolutbetrag), `VAT_TYPE` markiert ZAHLLAST/UEBERHANG/NEUTRAL** | [004](entscheidungen/004-saldo-vorzeichen.md) |
| 6 | Korrekturen-Modellierung | Beispiel hat eigene Zeile `K1235 -6,70` | MS4 mischt: Spalte auf Quellrechnung (`IS_CORRECTION`/`ORIGINAL_INVOICE_ID`) UND eigene Item-Zeile | **Eigene Zeile in T_VAT_STATEMENT_ITEM mit `IS_CORRECTION=1`, negativer Betrag, `ORIGINAL_INVOICE_ID` zeigt Ursprung** | [005](entscheidungen/005-korrekturen.md) |
| 7 | Unprofessioneller Satz in MS2 Ziel-Section | drin | n/a | **Vor jeder weiteren Abgabe-Version entfernen** | — |

## Weitere kleinere Diskrepanzen

- MS4 nennt im Überblick (2.1) ein Schema `lov_views`, im LOV-CREATE-Statement aber `lov_views.LOV_VAT_STATUS`. Tatsächlich verfügbares Schema laut HdM: `list_views`. → **`list_views.LOV_VAT_STATUS`**.
- MS4 erwähnt nicht explizit `ins_views` / `upd_views` für Frontend-Schreibzugriff. Da `ERP_REMOTE_USER` nur read/write/execute hat, brauchen wir vermutlich Wrapper-Views. → Stand jetzt über Stored Procs gelöst (`sp_create_vat_statement`, `sp_approve_*`, `sp_pay_*`, `sp_reject_*`), Insert/Update-Views aktuell nicht nötig.
- View-Namen im MS4: `OUTPUT_VAT_TOTAL` (Singular) vs. "OUTPUT_VAT_TOTALT" (Tippfehler). → mit HdM-Konventionen umbenannt zu `V_LIST_OUTPUT_VAT` (ADR-007).
- MS4 referenziert `T_INOVICE` an einer Stelle (Tippfehler) — gemeint ist `T_INVOICE`.
- **MS4 vs. tatsächliche Dev-DB:** MS4 nimmt an, dass `T_INVOICE` und `T_SUPPLIER_INVOICE` jeweils eine `TAX_AMOUNT`-Spalte auf Kopf-Ebene haben; der Snapshot vom 11.05.2026 zeigt: diese Roh-Spalten existieren nicht. Aktueller Soll-Stand (ADR-008/ADR-010): Wir aggregieren NICHT mehr selbst aus Items/`T_MATERIAL`. Stattdessen konsumiert `list_views.V_LIST_OUTPUT_VAT` den fertigen `TAX_AMOUNT` aus G7s Rechnungs-View (alle Ausgangsrechnungen inkl. G9/G10), `V_LIST_INPUT_VAT` die Vorsteuer aus G4, und `V_LIST_VAT_SKONTO` den finalen Steuerbetrag nach Skonto aus G8 (überschreibt den Rechnungsbetrag). Fehlt eine Quelle, läuft sie als Stub; Bring-Schuld liegt bei der Partner-Gruppe (Issues #24-#28).
- **Stored Procedure / Function Naming:** MS4 verwendet UPPER_CASE (`SF_CK_VAT_PERIOD`, `SP_CREATE_VAT_STATEMENT`). HdM-Konvention ist KLEIN. → ADR-007, alle Namen refactored.
