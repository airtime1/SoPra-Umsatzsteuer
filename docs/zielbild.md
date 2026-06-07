# Zielbild Umsatzsteuerabrechnung

Stand: 2026-06-07

Dieses Zielbild beschreibt den fachlich und technisch angestrebten Soll-Zustand des Moduls nach der kritischen Konzept- und DEV-DB-Pruefung. Die offiziellen Konzeptdateien in `docs/konzepte/` bleiben Referenzartefakte; dieses Dokument beschreibt den aktuell umsetzbaren Entwicklungsstand fuer App, SQL und Tests.

## Zweck des Moduls

Das Modul ist ein Abschluss- und Auswertungsmodul im groesseren SoPra-/ERP-System. Es erzeugt keine Rechnungen und korrigiert keine vorgelagerten Belege. Es konsumiert steuerrelevante Ausgangsrechnungen, Eingangsrechnungen und, soweit modelliert, Zahlungskorrekturen, friert diese je Abrechnungsperiode als Abrechnungsbeleg ein und fuehrt diesen durch einen einfachen Status-Workflow.

Fachliche Leitplanken:

- Monatliche Abrechnungsperiode im Format `YYYY-MM`.
- Abrechnung fruehestens ab dem 10. des Folgemonats, passend zur Grundlogik der Umsatzsteuer-Voranmeldung nach § 18 UStG.
- Zahllast oder Vorsteuerueberhang wird aus aggregierter Umsatzsteuer minus Vorsteuer ermittelt.
- Nachtraegliche Minderung der Bemessungsgrundlage, etwa durch Skonto, wird als eigene Korrekturzeile behandelt; das passt zur Korrekturlogik nach § 17 UStG.
- Abgerechnete Perioden werden nicht mutiert. Spaet eintreffende Korrekturen landen ueber ihr eigenes Beleg-/Korrekturdatum in einer spaeteren offenen Periode.

Referenzquellen: [§ 18 UStG](https://www.gesetze-im-internet.de/ustg_1980/__18.html), [§ 17 UStG](https://www.gesetze-im-internet.de/ustg_1980/__17.html).

## Periodenlogik

`VAT_PERIOD` ist ein Monatswert `YYYY-MM`. Die Datenbank prueft:

- Format und gueltigen Monat.
- Frueheste Anlage: 10. Tag des Folgemonats.
- Maximal eine Abrechnung pro Periode ueber eine eindeutige Periodenregel.
- Re-Berechnung ist nur fuer `DRAFT` erlaubt.
- `APPROVED` und `PAID` sperren die Periode gegen Neuberechnung.

Die Streamlit-Seite `Neue Abrechnung` schlaegt nur die letzte bereits abrechenbare Periode vor. Die verbindliche Sperre bleibt in `stored_func.fn_check_vat_period`.

## Berechnung

`stored_proc.sp_create_vat_statement` liest die einheitlichen Schnittstellen-Views:

- `list_views.V_LIST_OUTPUT_VAT`: Umsatzsteuer aus Ausgangsrechnungen und optional Zahlungskorrekturen.
- `list_views.V_LIST_INPUT_VAT`: Vorsteuer aus Eingangsrechnungen.

Die Procedure speichert die Quellzeilen in `dbo.T_VAT_STATEMENT_ITEM`. Dadurch bleibt die Belegbasis der Abrechnung nachvollziehbar, selbst wenn vorgelagerte Module spaeter weitere Daten liefern.

`stored_func.fn_calculate_vat_balance` berechnet:

- `OUTPUT_VAT_TOTAL`: Summe der Umsatzsteuerfaelle, inkl. negativer Korrekturzeilen.
- `INPUT_VAT_TOTAL`: Summe der Vorsteuerfaelle.
- `VAT_BALANCE`: nicht-negativer Absolutbetrag.
- `VAT_TYPE`: `ZAHLLAST`, `UEBERHANG` oder `NEUTRAL`.

## Korrekturen, Skonto und Storno

Korrekturen werden nicht durch Veraenderung alter `T_VAT_STATEMENT_ITEM`-Zeilen abgebildet, sondern als neue steuerliche Ereignisse:

- `IS_CORRECTION=1` markiert Korrekturzeilen.
- `ORIGINAL_INVOICE_ID` verweist, falls vorhanden, auf den Ursprungsbeleg.
- `SOURCE_INVOICE_DATE` steuert die Abrechnungsperiode der Korrektur.

Aktuell nutzt `V_LIST_OUTPUT_VAT` optionale Spalten aus `dbo.T_PAYMENT_RECEIPT`, wenn sie vorhanden sind. Ein Skonto- oder Zahlungsdifferenzbetrag wird anteilig auf den Steueranteil der Ursprungsrechnung umgerechnet und als negative Umsatzsteuerzeile ausgegeben. In aelteren Sandbox-Staenden fehlen diese Spalten noch; dann bleibt die Korrektur-Schnittstelle als erkannte Luecke dokumentiert und die View liefert nur Rechnungssteuer.

Storno und Teilstorno sind fachlich vorbereitet, aber nicht final entschieden, weil die verbindliche Schnittstelle der Partnergruppen noch fehlt.

## Status und Rollen

Statusmodell:

- `DRAFT`: erzeugt oder neu berechnet; fachlich pruefbar.
- `APPROVED`: durch CFO freigegeben; nicht mehr neu berechenbar.
- `PAID`: durch Leitung FiBu abgeschlossen; Periode bleibt gesperrt.

Erlaubte Statusfolgen:

- `DRAFT -> APPROVED`: CFO, `SECURITYLEVEL=3`.
- `APPROVED -> DRAFT`: CFO, `SECURITYLEVEL=3`, fachliche Rueckgabe.
- `APPROVED -> PAID`: Leitung FiBu, `SECURITYLEVEL=2`.

Die Anlage einer Abrechnung ist Sachbearbeiter-Aufgabe (`SECURITYLEVEL=1`). Die Stored Procedures pruefen die Rolle ueber `dbo.T_USER.SECURITYLEVEL` und die fuer `VAT_STATUS` hinterlegten `dbo.T_CODE_NEXT.SECURITY_LEVEL`-Regeln. Die UI bietet nur passende Benutzer aus `list_views.V_LIST_VAT_USER` an, ersetzt aber keine echte Authentifizierung.

## Integration

Die App soll keine eigenen Kopien fremder Rechnungsdaten pflegen. Partnerdaten werden ueber Views gelesen und in den Abrechnungsbeleg als Snapshot uebernommen:

- Ausgangsrechnungen: Gruppe 7, `dbo.T_INVOICE` / `dbo.T_INVOICE_ITEM`.
- Eingangsrechnungen: Gruppe 4, `dbo.T_SUPPLIER_INVOICE` / `dbo.T_SUPPLIER_INVOICE_ITEM`.
- Zahlung/Skonto/Storno: Gruppe 8, `dbo.T_PAYMENT_RECEIPT`, soweit die Spalten in der Ziel-DB vorhanden und gepflegt sind.
- Status und Rollen: zentrale Tabellen `dbo.T_CODE`, `dbo.T_CODE_NEXT`, `dbo.T_USER`.

Wenn eine Partnergruppe ihre finale Schnittstelle aendert, soll primaer die jeweilige `list_views.V_LIST_*`-View angepasst werden. Stored Procedures, App-Services und Tests bleiben dadurch moeglichst stabil.

## Nicht-Ziele

- Keine elektronische Uebermittlung an das Finanzamt.
- Keine vollstaendige Finanzbuchhaltung.
- Keine Rechnungserstellung oder Rechnungskorrektur in vorgelagerten Modulen.
- Keine fachliche Steuerberatung und keine produktionsreife Compliance-Software.
- Keine echte Authentifizierung im Streamlit-Prototyp; die DB-Rollenpruefung bildet den fachlichen Workflow fuer die Demo ab.
