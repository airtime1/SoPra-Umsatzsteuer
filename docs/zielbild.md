# Zielbild Umsatzsteuerabrechnung

Stand: 2026-06-15

Dieses Zielbild beschreibt den fachlich und technisch angestrebten Soll-Zustand des Moduls. Die offiziellen Konzeptdateien in `docs/konzepte/` bleiben Referenzartefakte; dieses Dokument beschreibt den aktuell umsetzbaren Entwicklungsstand fuer App, SQL und Tests.

## Zweck des Moduls

Das Modul ist ein Abschluss- und Auswertungsmodul im groesseren SoPra-/ERP-System. Es erzeugt keine Rechnungen und korrigiert keine vorgelagerten Belege. Es **konsumiert** steuerrelevante Belege von Partner-Gruppen, friert sie je Abrechnungsperiode als Abrechnungsbeleg ein und fuehrt diesen durch einen Status-Workflow.

Fachliche Leitplanken:

- Monatliche Abrechnungsperiode im Format `YYYY-MM`.
- Abrechnung fruehestens ab dem 10. des Folgemonats (siehe Periodenlogik).
- Zahllast oder Vorsteuerueberhang = aggregierte Umsatzsteuer minus Vorsteuer, abzueglich Skonto-Korrekturen.
- Nachtraegliche Minderung der Bemessungsgrundlage (Skonto) wird als eigene Korrekturzeile behandelt (Korrekturlogik nach § 17 UStG).
- Abgerechnete Perioden werden nicht mutiert. Spaet eintreffende Korrekturen landen ueber ihr eigenes Beleg-/Korrekturdatum in einer spaeteren offenen Periode.

Referenzquellen: [§ 18 UStG](https://www.gesetze-im-internet.de/ustg_1980/__18.html), [§ 17 UStG](https://www.gesetze-im-internet.de/ustg_1980/__17.html).

## Datenquellen und Verantwortungsteilung

Gruppe 15 berechnet **keine** Steuerbetraege selbst (ADR-008). Wir lesen die nach Konvention vereinbarten Werte (`RechnungsID`, `RechnungsDatum`, `Steuerbetrag` bzw. `Steuerkorrekturbetrag`) direkt aus der jeweiligen Partner-Lese-View. Wenn ein Partner-Feld oder eine Partner-View fehlt, ist das die Bring-Schuld der Partner-Gruppe; wir ergaenzen sie nicht.

Fuenf Quellen, drei fachliche Kategorien:

| Quelle | Gruppe | Kategorie | Liefert |
|---|---|---|---|
| Rechnungen Fernabsatz | G7 | Umsatzsteuer (Output) | RechnungsID, RechnungsDatum, Steuerbetrag (USt) |
| Barrechnung Rosenberg | G9 | Umsatzsteuer (Output) | RechnungsID, RechnungsDatum, Steuerbetrag (USt) |
| Barrechnung Freiburg | G10 | Umsatzsteuer (Output) | RechnungsID, RechnungsDatum, Steuerbetrag (USt) |
| Wareneingaenge | G4 | Vorsteuer (Input) | RechnungsID, RechnungsDatum, Steuerbetrag (VSt) |
| Zahlungseingaenge | G8 | Umsatzsteuer-Korrektur | RechnungsID, RechnungsDatum, Steuerkorrekturbetrag |

G7, G9 und G10 sind fachlich gleichwertig: drei Verkaufskanaele, die alle Umsatzsteuer erzeugen. In `V_LIST_OUTPUT_VAT` laufen sie per `UNION ALL` zusammen.

## Skonto-Korrektur (Gruppe 8)

Die Zahlungseingangsgruppe wird nur relevant, wenn eine Rechnung **mit Skonto** gezahlt wurde (Skontofrist max. 7 Tage). Hintergrund:

- Die Ursprungsrechnung (G7/G9/G10) wurde mit dem **vollen** Steuerbetrag erfasst.
- Wird Skonto beansprucht, mindert sich der zu versteuernde Betrag um den Skonto-Anteil. Der urspruenglich gebuchte USt-Betrag stimmt dann nicht mehr.
- Gruppe 8 berechnet daraus einen **Steuerkorrekturbetrag** und liefert ihn (positiv) ueber ihre View. Wir negieren ihn in `V_LIST_OUTPUT_VAT` und fuehren ihn als Korrekturzeile (`IS_CORRECTION=1`), sodass er die Umsatzsteuer mindert.

Wir rechnen den Steueranteil **nicht** selbst aus einem Brutto-Differenzbetrag — das ist Gruppe 8s Aufgabe (ADR-008). Eine Korrektur kann konstruktionsbedingt nur aus G8 kommen; G7/G9/G10 liefern nie Korrekturen.

## Periodenlogik

`VAT_PERIOD` ist ein Monatswert `YYYY-MM`. Zwei Datums-Regeln, die nicht verwechselt werden duerfen:

1. **Zuordnung der Belege zur Periode** laeuft ausschliesslich ueber das **Rechnungsdatum**: Eine Abrechnung fuer `2026-03` bezieht genau die Belege mit Rechnungsdatum im Maerz ein (`SOURCE_INVOICE_DATE BETWEEN @period_start AND @period_end` in `sp_create_vat_statement`).
2. **Frueheste Abrechenbarkeit** ist der 10. des Folgemonats. Grund: Bis dahin ist die 7-Tage-Skontofrist abgelaufen, also stehen alle Skonto-Korrekturen fest und die Abrechnung muss nicht nachtraeglich angepasst werden. Das passt zugleich zur Grundlogik der Umsatzsteuer-Voranmeldung nach § 18 UStG. Diese Frist-Pruefung vergleicht das heutige Datum mit der Frist und steckt in `stored_func.fn_check_vat_period`.

Weiter gilt:

- Format und gueltiger Monat werden geprueft.
- Maximal eine Abrechnung pro Periode (eindeutige Periodenregel).
- Re-Berechnung ist nur fuer `DRAFT` erlaubt; `APPROVED`/`PAID` sperren die Periode.

Die Streamlit-Seite `Neue Abrechnung` schlaegt nur die letzte bereits abrechenbare Periode vor. Die verbindliche Sperre bleibt in `stored_func.fn_check_vat_period`.

## Berechnung

`stored_proc.sp_create_vat_statement` liest die einheitlichen Schnittstellen-Views:

- `list_views.V_LIST_OUTPUT_VAT`: Umsatzsteuer aus G7/G9/G10 plus Skonto-Korrekturen aus G8.
- `list_views.V_LIST_INPUT_VAT`: Vorsteuer aus G4.

Beide Views liefern eine stabile Spalten-Signatur (`SOURCE_TABLE`, `SOURCE_INVOICE_ID`, `SOURCE_INVOICE_DATE`, `INVOICE_ID`, `INVOICE_DATE`, `TAX_AMOUNT`, `IS_CORRECTION`, `ORIGINAL_INVOICE_ID`). Die Procedure speichert die Quellzeilen in `dbo.T_VAT_STATEMENT_ITEM`, damit die Belegbasis nachvollziehbar bleibt.

`stored_func.fn_calculate_vat_balance` berechnet:

- `OUTPUT_VAT_TOTAL`: Summe Umsatzsteuer (G7/G9/G10) inkl. negativer Skonto-Korrekturen (G8).
- `INPUT_VAT_TOTAL`: Summe Vorsteuer (G4).
- `VAT_BALANCE`: nicht-negativer Absolutbetrag der Differenz.
- `VAT_TYPE`: `ZAHLLAST`, `UEBERHANG` oder `NEUTRAL`.

### Stub-Pattern fuer noch nicht gelieferte Quellen

Solange eine Partner-View oder ein Partner-Feld fehlt, laeuft der zugehoerige `UNION ALL`-Zweig als **Stub**: korrekte Spalten-Signatur, aber `WHERE 1 = 0` (null Zeilen). Der echte Aktivierungs-SELECT steht im View-File als Kommentar bereit und wird ohne weitere Aenderung eingesetzt, sobald die Partner-Gruppe liefert. Stand 2026-06-15: G7 aktiv; G9, G10, G8 und G4 als Stub (siehe `docs/schnittstellen_annahmen.md`).

## Korrekturen, Skonto und Storno

Korrekturen werden nicht durch Veraenderung alter `T_VAT_STATEMENT_ITEM`-Zeilen abgebildet, sondern als neue steuerliche Ereignisse (ADR-005):

- `IS_CORRECTION=1` markiert Korrekturzeilen (nur aus G8).
- `ORIGINAL_INVOICE_ID` verweist auf den Ursprungsbeleg.
- `SOURCE_INVOICE_DATE` steuert die Abrechnungsperiode der Korrektur.

Storno und Teilstorno sind fachlich vorbereitet, aber nicht final entschieden, weil die verbindliche Schnittstelle der Partnergruppen noch fehlt.

## Status und Rollen

Statusmodell:

- `DRAFT`: erzeugt oder neu berechnet; fachlich pruefbar.
- `APPROVED`: durch CFO freigegeben; nicht mehr neu berechenbar.
- `PAID`: durch Leitung FiBu abgeschlossen; Periode bleibt gesperrt.

Erlaubte Statusfolgen (in `dbo.T_CODE_NEXT` hinterlegt):

- `DRAFT -> APPROVED`: CFO, `SECURITYLEVEL=3`.
- `APPROVED -> DRAFT`: CFO, `SECURITYLEVEL=3`, fachliche Rueckgabe.
- `APPROVED -> PAID`: Leitung FiBu, `SECURITYLEVEL=2`.

Die Anlage einer Abrechnung ist Sachbearbeiter-Aufgabe (`SECURITYLEVEL=1`).

Die Status-Procedures pruefen die **Gueltigkeit** eines Uebergangs ueber die zentrale Architekten-Function `dbo.fn_chk_status_folge` (liest `dbo.T_CODE_NEXT`, ADR-009) und die **Rolle** ueber `dbo.T_USER.SECURITYLEVEL` gegen den `SECURITY_LEVEL` der Transition. `T_CODE_NEXT` ist dabei die Konfiguration (welche Uebergaenge, welche Rolle), die Procedure fuehrt den eigentlichen Statuswechsel plus Audit-Felder aus. Die UI bietet nur passende Benutzer aus `list_views.V_LIST_VAT_USER` an, ersetzt aber keine echte Authentifizierung.

## Integration

Die App pflegt keine eigenen Kopien fremder Rechnungsdaten. Partnerdaten werden ueber deren `list_views.V_LIST_*`-Views gelesen und in den Abrechnungsbeleg als Snapshot uebernommen:

- Umsatzsteuer: `list_views.V_LIST_G07_INVOICE` (G7, aktiv), `list_views.V_LIST_G09_INVOICE_TAX_B2C` (G9, Stub), G10-View (noch offen, Stub).
- Vorsteuer: G4-View `list_views.V_LIST_G04_SUPPLIER_INVOICE` (noch offen, Stub).
- Skonto-Korrektur: `list_views.V_LIST_G08_PAYMENT_RECEIPT` (G8, Stub bis `TAX_CORRECTION_AMOUNT` geliefert).
- Status, Rollen, zentrale Bausteine: `dbo.T_CODE`, `dbo.T_CODE_NEXT`, `dbo.T_USER`, `dbo.fn_chk_status_folge`.

Wenn eine Partnergruppe ihre Schnittstelle aendert, wird primaer die eigene `list_views.V_LIST_*`-View (bzw. der Stub-Block) angepasst. Stored Procedures, App-Services und Tests bleiben dadurch stabil.

## Nicht-Ziele

- Keine elektronische Uebermittlung an das Finanzamt.
- Keine vollstaendige Finanzbuchhaltung.
- Keine Rechnungserstellung oder Rechnungskorrektur in vorgelagerten Modulen.
- Keine eigene Steuerberechnung aus Roh-Belegen (ADR-008).
- Keine fachliche Steuerberatung und keine produktionsreife Compliance-Software.
- Keine echte Authentifizierung im Streamlit-Prototyp; die DB-Rollenpruefung bildet den fachlichen Workflow fuer die Demo ab.
