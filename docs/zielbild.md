# Zielbild Umsatzsteuerabrechnung

Stand: 2026-06-16

Dieses Zielbild beschreibt den fachlich und technisch angestrebten Soll-Zustand des Moduls. Die offiziellen Konzeptdateien in `docs/konzepte/` bleiben Referenzartefakte; dieses Dokument beschreibt den aktuell umsetzbaren Entwicklungsstand fuer App, SQL und Tests.

## Zweck des Moduls

Das Modul ist ein Abschluss- und Auswertungsmodul im groesseren SoPra-/ERP-System. Es erzeugt keine Rechnungen und korrigiert keine vorgelagerten Belege. Es **konsumiert** steuerrelevante Belege von Partner-Gruppen, friert sie je Abrechnungsperiode als Abrechnungsbeleg ein und fuehrt diesen durch einen Status-Workflow.

Fachliche Leitplanken:

- Monatliche Abrechnungsperiode im Format `YYYY-MM`.
- Abrechnung fruehestens ab dem 10. des Folgemonats (siehe Periodenlogik).
- Zahllast oder Vorsteuerueberhang = aggregierte Umsatzsteuer minus Vorsteuer, jeweils inkl. Skonto-Minderung.
- Nachtraegliche Minderung der Bemessungsgrundlage (Skonto) wird durch **Ueberschreiben** des finalen Steuerbetrags der Rechnung abgebildet (ADR-010, § 17 UStG), nicht mehr als eigene Korrekturzeile.
- Abgerechnete Perioden werden nicht mutiert. Durch die 7-Tage-Skontofrist + 10.-des-Folgemonats-Regel stehen alle Skonto-Korrekturen einer Periode bei deren Abrechnung bereits fest.

Referenzquellen: [§ 18 UStG](https://www.gesetze-im-internet.de/ustg_1980/__18.html), [§ 17 UStG](https://www.gesetze-im-internet.de/ustg_1980/__17.html).

## Datenquellen und Verantwortungsteilung

Gruppe 15 berechnet **keine** Steuerbetraege selbst (ADR-008). Wir lesen die nach Konvention vereinbarten Werte (`RechnungsID`, `RechnungsDatum`, `Steuerbetrag`) direkt aus der jeweiligen Partner-Lese-View. Wenn ein Partner-Feld oder eine Partner-View fehlt, ist das die Bring-Schuld der Partner-Gruppe; wir ergaenzen sie nicht.

Drei fachliche Kategorien (Beschluss 2026-06-16):

| Quelle | Gruppe | Kategorie | Liefert |
|---|---|---|---|
| alle Ausgangsrechnungen | G7 | Umsatzsteuer (Output) | RechnungsID, RechnungsDatum, Steuerbetrag (USt) |
| Wareneingaenge | G4 | Vorsteuer (Input) | RechnungsID, RechnungsDatum, Steuerbetrag (VSt) |
| Zahlungseingaenge | G8 | Skonto (finaler Steuerbetrag) | RechnungsID, finaler Steuerbetrag, `IS_SKONTO` |

Die Barverkaeufe von G9 (Rosenberg) und G10 (Freiburg) sind keine eigenen Quellen mehr: sie schreiben ueber dieselbe `dbo.T_INVOICE` wie G7 und werden ueber `V_LIST_G07_INVOICE` mitgeliefert. Damit ist G7 die **eine** Output-Quelle. (Bring-Schuld G7: die View muss noch alle T_INVOICE-Rechnungen liefern, nicht nur die Fernabsatz-Kette — Diagnose 2026-06-16: 78 von 156 G9-Rechnungen sichtbar.)

## Skonto-Korrektur (Gruppe 8)

Die Zahlungseingangsgruppe wird nur relevant, wenn eine Rechnung **mit Skonto** gezahlt wurde (Skontofrist max. 7 Tage). Hintergrund:

- Die Ursprungsrechnung wurde mit dem **vollen** Steuerbetrag erfasst.
- Wird Skonto beansprucht, mindert sich der zu versteuernde Betrag um den Skonto-Anteil. Der urspruenglich gebuchte USt-Betrag stimmt dann nicht mehr.
- Gruppe 8 liefert je Zahlungseingang den **finalen** Steuerbetrag der Rechnung nach Skonto plus `IS_SKONTO` (Y/N). Bei `IS_SKONTO='Y'` ueberschreibt `sp_G15_create_vat_statement` den urspruenglichen Steuerbetrag der Rechnung (Match ueber `INVOICE_ID`, ADR-010).

Wir rechnen den Steueranteil **nicht** selbst aus einem Brutto-Differenzbetrag — das ist Gruppe 8s Aufgabe (ADR-008). Skonto-Korrekturen kommen ausschliesslich aus G8.

## Periodenlogik

`VAT_PERIOD` ist ein Monatswert `YYYY-MM`. Zwei Datums-Regeln, die nicht verwechselt werden duerfen:

1. **Zuordnung der Belege zur Periode** laeuft ausschliesslich ueber das **Rechnungsdatum**: Eine Abrechnung fuer `2026-03` bezieht genau die Belege mit Rechnungsdatum im Maerz ein (`SOURCE_INVOICE_DATE BETWEEN @period_start AND @period_end` in `sp_G15_create_vat_statement`).
2. **Frueheste Abrechenbarkeit** ist der 10. des Folgemonats. Grund: Bis dahin ist die 7-Tage-Skontofrist abgelaufen, also stehen alle Skonto-Korrekturen fest und die Abrechnung muss nicht nachtraeglich angepasst werden. Das passt zugleich zur Grundlogik der Umsatzsteuer-Voranmeldung nach § 18 UStG. Diese Frist-Pruefung vergleicht das heutige Datum mit der Frist und steckt in `stored_func.fn_G15_check_vat_period`.

Weiter gilt:

- Format und gueltiger Monat werden geprueft.
- Maximal eine Abrechnung pro Periode (eindeutige Periodenregel).
- Re-Berechnung ist nur fuer `DRAFT` erlaubt; `APPROVED`/`PAID` sperren die Periode.

Die Streamlit-Seite `Neue Abrechnung` schlaegt nur die letzte bereits abrechenbare Periode vor. Die verbindliche Sperre bleibt in `stored_func.fn_G15_check_vat_period`.

## Berechnung

`stored_proc.sp_G15_create_vat_statement` liest die einheitlichen Schnittstellen-Views:

- `list_views.V_LIST_G15_OUTPUT_VAT`: Umsatzsteuer aus allen Ausgangsrechnungen (G7-View).
- `list_views.V_LIST_G15_INPUT_VAT`: Vorsteuer aus G4.
- `list_views.V_LIST_G15_VAT_SKONTO`: finaler Steuerbetrag je Rechnung aus G8 (Quelle fuer den Ueberschreib-Schritt, ADR-010).

Die beiden Item-Views liefern eine stabile Spalten-Signatur (`SOURCE_TABLE`, `SOURCE_INVOICE_ID`, `SOURCE_INVOICE_DATE`, `INVOICE_ID`, `INVOICE_DATE`, `TAX_AMOUNT`, `IS_CORRECTION`, `ORIGINAL_INVOICE_ID`). Die Procedure speichert die Quellzeilen in `dbo.T_VAT_STATEMENT_ITEM`, ueberschreibt anschliessend Skonto-Rechnungen mit dem finalen Betrag, damit die Belegbasis nachvollziehbar bleibt.

`stored_func.fn_G15_calculate_vat_balance` berechnet:

- `OUTPUT_VAT_TOTAL`: Summe Umsatzsteuer (T_INVOICE), Skonto bereits im Betrag eingerechnet.
- `INPUT_VAT_TOTAL`: Summe Vorsteuer (G4).
- `VAT_BALANCE`: nicht-negativer Absolutbetrag der Differenz.
- `VAT_TYPE`: `ZAHLLAST`, `UEBERHANG` oder `NEUTRAL`.

### Stub-Pattern fuer noch nicht gelieferte Quellen

Solange eine Partner-View oder ein Partner-Feld fehlt, laeuft die zugehoerige Quelle als **Stub**: korrekte Spalten-Signatur, aber `WHERE 1 = 0` (null Zeilen). Der echte Aktivierungs-SELECT steht im View-File als Kommentar bereit und wird ohne weitere Aenderung eingesetzt, sobald die Partner-Gruppe liefert. Stand 2026-06-23: G7 aktiv (nur Fernabsatz, B2C-Erweiterung offen); `V_LIST_G15_INPUT_VAT` (G4) aktiv auf `V_LIST_SUPPLIER_INVOICE` (0 Zeilen bis G4 Daten einspielt); `V_LIST_G15_VAT_SKONTO` (G8) weiterhin Stub, weil der finale Steuerbetrag nach Skonto fehlt (siehe `docs/schnittstellen_annahmen.md`).

## Korrekturen, Skonto und Storno

Skonto-Korrekturen werden durch **Ueberschreiben** des finalen Steuerbetrags der Rechnung abgebildet (ADR-010, loest ADR-005 ab):

- `IS_CORRECTION=1` markiert die durch Skonto ueberschriebene Zeile.
- `ORIGINAL_INVOICE_ID` zeigt auf dieselbe Rechnung (erfuellt den Constraint, behaelt die Audit-Spur).
- Der finale Betrag kommt aus `list_views.V_LIST_G15_VAT_SKONTO` (G8).

Storno und Teilstorno sind fachlich vorbereitet, aber nicht final entschieden, weil die verbindliche Schnittstelle der Partnergruppen noch fehlt.

## Status und Rollen

Statusmodell:

- `DRAFT`: erzeugt oder neu berechnet; fachlich pruefbar.
- `APPROVED`: durch CFO freigegeben; nicht mehr neu berechenbar.
- `PAID`: durch Leitung FiBu abgeschlossen; Periode bleibt gesperrt.

Erlaubte Statusfolgen (in `dbo.T_CODE_NEXT` hinterlegt):

- `DRAFT -> APPROVED`: Mindest-Level 3 (CFO).
- `APPROVED -> DRAFT`: Mindest-Level 3 (CFO), fachliche Rueckgabe.
- `APPROVED -> PAID`: Mindest-Level 2 (Leitung FiBu).

Die Anlage einer Abrechnung ist eine Level-1-Aktion (`SECURITYLEVEL >= 1`).

Die Status-Procedures pruefen die **Gueltigkeit** eines Uebergangs ueber die zentrale Architekten-Function `dbo.fn_chk_status_folge` (liest `dbo.T_CODE_NEXT`, ADR-009) und die **Rolle** hierarchisch ueber `dbo.T_USER.SECURITYLEVEL` gegen den Mindest-`SECURITY_LEVEL` der Transition (`actual_level >= required_level`, ADR-011). `T_CODE_NEXT` ist dabei die Konfiguration (welche Uebergaenge, welcher Mindest-Level), die Procedure fuehrt den eigentlichen Statuswechsel plus Audit-Felder aus. Uebergebene Audit-User muessen dem aktuellen `SUSER_SNAME()` entsprechen, damit direkte Procedure-Aufrufe keinen fremden User vortaeuschen koennen. Die UI nutzt denselben Mindest-Level fuer sichtbare Aktionen.

Die App hat keine manuelle Rollensimulation mehr. Der Benutzer meldet sich mit seinem echten DB-Zugang an; die UI ermittelt den Login via `SUSER_SNAME()` und den Level via `dbo.fn_get_user_securitylevel(SUSER_SNAME())`. Audit-Spalten verwenden diesen echten DB-User.

## Integration

Die App pflegt keine eigenen Kopien fremder Rechnungsdaten. Partnerdaten werden ueber deren `list_views.V_LIST_*`-Views gelesen und in den Abrechnungsbeleg als Snapshot uebernommen:

- Umsatzsteuer: `list_views.V_LIST_G07_INVOICE` (G7, aktiv; liefert alle Ausgangsrechnungen, sobald die View B2C einschliesst).
- Vorsteuer: G4-View `list_views.V_LIST_SUPPLIER_INVOICE` (aktiv seit 23.06., `TOTAL_VAT_AMOUNT`; 0 Zeilen bis G4 Daten einspielt).
- Skonto: `list_views.V_LIST_G08_PAYMENT_RECEIPT` (G8; Skonto-Flag `SKONTO_BERECHTIGT_YN` da, Stub bis finaler Steuerbetrag nach Skonto geliefert wird).
- Status, Rollen, zentrale Bausteine: `dbo.T_CODE`, `dbo.T_CODE_NEXT`, `dbo.T_USER`, `dbo.fn_chk_status_folge`, `dbo.fn_get_user_securitylevel`.

Wenn eine Partnergruppe ihre Schnittstelle aendert, wird primaer die eigene `list_views.V_LIST_*`-View (bzw. der Stub-Block) angepasst. Stored Procedures, App-Services und Tests bleiben dadurch stabil.

## Nicht-Ziele

- Keine elektronische Uebermittlung an das Finanzamt.
- Keine vollstaendige Finanzbuchhaltung.
- Keine Rechnungserstellung oder Rechnungskorrektur in vorgelagerten Modulen.
- Keine eigene Steuerberechnung aus Roh-Belegen (ADR-008).
- Keine fachliche Steuerberatung und keine produktionsreife Compliance-Software.
- Keine produktionsreife Web-Session-Verwaltung; Streamlit haelt die eingegebenen DB-Credentials nur im laufenden Session-State.
