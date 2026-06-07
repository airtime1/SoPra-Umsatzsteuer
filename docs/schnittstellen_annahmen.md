# Schnittstellen und Annahmen

Stand: 2026-06-07

Dieses Dokument fasst die lesende Analyse der gemeinsamen DEV-Datenbank `ERPDEV26S` und die daraus abgeleiteten Annahmen fuer das Umsatzsteuer-Modul zusammen. Es enthaelt keine Credentials und keine Connection Strings.

## Gepruefte DEV-Bereiche

| Bereich | Befund | Nutzung im Modul |
|---|---|---|
| `dbo.T_INVOICE` | Ausgangsrechnungskopf vorhanden; in DEV 155 Datensaetze; relevante Statuswerte u. a. `SEND TO CUSTOMER`, `OVERDUE`, `PAID`. | Quelle fuer steuerlich relevante Ausgangsrechnungen. |
| `dbo.T_INVOICE_ITEM` | Detailpositionen vorhanden. DEV hat detaillierte Wertspalten; bekannte Sandbox kann aelter sein und nur Material/Menge enthalten. | Umsatzsteuer wird itembasiert berechnet, nicht aus einer Kopf-`TAX_AMOUNT`-Spalte. |
| `dbo.T_MATERIAL` | Materialpreise und `VAT` vorhanden. | Fallback fuer aeltere Sandbox-Staende und fehlende Item-Steuerwerte. |
| `dbo.T_SUPPLIER_INVOICE` | Eingangsrechnungskopf vorhanden; DEV aktuell ohne Daten. | Quelle fuer Vorsteuer, sobald Partnerdaten vorhanden sind. |
| `dbo.T_SUPPLIER_INVOICE_ITEM` | Positionen mit Preis-/Mengen-/Steuersatzlogik vorhanden; `UNIT_NET_VALUE` kann berechnet oder als computed column vorhanden sein. | Vorsteuer wird aus Itemwerten und `UNIT_VAT_PCT` aggregiert. |
| `dbo.T_PAYMENT_RECEIPT` | Zahlungseingaenge vorhanden; DEV hat Skonto-/Storno-nahe Spalten, diese sind aktuell aber praktisch nicht gefuellt. Bekannte Sandbox kann diese Spalten noch nicht haben. | Optionale Quelle fuer Skonto- und spaete Korrekturzeilen. |
| `dbo.T_CODE` | Zentrale Status-/Code-Tabelle vorhanden. | Statusnamen fuer Rechnungen, Lieferantenrechnungen, Zahlungen und VAT-Status. |
| `dbo.T_CODE_NEXT` | Statusfolge-Tabelle mit `SECURITY_LEVEL` vorhanden. | Rollencheck fuer VAT-Statuswechsel. |
| `dbo.T_USER` | Benutzer mit `SECURITYLEVEL` vorhanden. | Demo-Rollen: 1 Sachbearbeiter, 2 Leitung FiBu, 3 CFO. |
| `list_views.V_LIST_G07_INVOICE*` | Gruppen-Views vorhanden, liefern aber in Stichproben keine belastbaren Steuerbetraege. | Nicht primaere Quelle; direkte Tabellenaggregation ist derzeit plausibler. |
| `list_views.V_LIST_G08_PAYMENT_*` | Zahlungsbezogene Views vorhanden. | Beobachtet, aber wegen unklarer Skonto-/Storno-Semantik nicht direkt als Hauptschnittstelle verwendet. |

## Aktuelle Schnittstellenentscheidung

Die Umsatzsteuer-App konsumiert Partnerdaten nicht direkt im Frontend, sondern ueber eigene Lese-Views:

- `list_views.V_LIST_OUTPUT_VAT` vereinheitlicht Ausgangsrechnungen und optionale Zahlungskorrekturen.
- `list_views.V_LIST_INPUT_VAT` vereinheitlicht Eingangsrechnungen/Vorsteuer.
- `list_views.V_LIST_VAT_STATEMENT` und `list_views.V_LIST_VAT_STATEMENT_ITEM` kapseln eigene Abrechnungstabellen fuer die UI.
- `list_views.V_LIST_VAT_USER` stellt nur Login, Security-Level und Demo-Rolle bereit; keine Passwortdaten.

Diese Entscheidung reduziert Duplikation: Steuerrelevante Rechnungsdaten bleiben in den Partner-Modulen, die Umsatzsteuerabrechnung speichert nur den Abrechnungssnapshot.

## Annahmen fuer den aktuellen Stand

- Eine Ausgangsrechnung wird steuerlich beruecksichtigt, wenn ihr Statusname `SEND TO CUSTOMER`, `OVERDUE` oder `PAID` ist.
- Eine Eingangsrechnung wird steuerlich beruecksichtigt, wenn ihr Statusname `AN BUCHHALTUNG UEBERMITTELT` ist.
- Steuerbetraege werden aus Positionen berechnet, solange keine belastbare, zentrale Steuerbetragsspalte auf den Rechnungskopf-Tabellen existiert.
- Negative Korrekturen aus Zahlungseingaengen sind nur dann aktiv, wenn die benoetigten `T_PAYMENT_RECEIPT`-Spalten im Zielsystem vorhanden und gepflegt sind.
- Der Korrekturmonat ergibt sich aus dem Belegdatum der Korrektur (`SOURCE_INVOICE_DATE`), nicht aus dem Datum der Ursprungsrechnung.
- Rollenpruefung erfolgt ueber `T_USER.SECURITYLEVEL`; die Streamlit-Auswahl ist nur Demo-Bedienung.
- `dbo.T_VAT_STATEMENT` und `dbo.T_VAT_STATEMENT_ITEM` liegen fachlich in `dbo`, werden in der gemeinsamen DEV-DB aber nur ueber den Architekten angelegt.

## Offene Fragen an Partnergruppen / Dozent

- Gruppe 7: Welche finale Schnittstelle markiert Storno, Teilstorno, Gutschrift oder Korrekturrechnung fuer Ausgangsrechnungen?
- Gruppe 7: Bleibt die Steuerberechnung dauerhaft itembasiert, oder kommt eine verbindliche Kopf-`TAX_AMOUNT`-Spalte?
- Gruppe 4: Welche finalen Statuswerte bedeuten steuerlich "vorsteuerrelevant"?
- Gruppe 4: Wird Vorsteuer dauerhaft aus `T_SUPPLIER_INVOICE_ITEM` berechnet oder als gepruefter Steuerbetrag geliefert?
- Gruppe 8: Welche Semantik haben `DIFFERENCE_AMOUNT`, `SKONTO_BERECHTIGT_YN`, `STORNO_YN` und `STORNO_REFERENCE_ID` verbindlich?
- Gruppe 8: Sollen Zahlungsdifferenzen netto/brutto geliefert werden, oder muessen wir den Steueranteil proportional aus der Rechnung ableiten?
- Architekt/Dozent: Bestaetigung der `VAT_STATUS`-IDs 9001 bis 9003 oder Zuteilung finaler IDs im zentralen Codebereich.
- Architekt/Dozent: Bestaetigung, ob `T_VAT_STATEMENT`-Schutz gegen direkte Updates ueber Rechte ausreicht oder ein eigener Trigger verlangt wird.

## Uebergangsloesung

Bis die Schnittstellen final sind, gilt:

- Partnerdaten werden nur gelesen.
- Unsere fachliche Logik haengt an den eigenen `list_views.V_LIST_*`-Views.
- DEV-Analyse bleibt lesend; Testdaten werden nur in der Sandbox erzeugt.
- Die Demo-Seed-Daten decken Ausgangsrechnungen, Eingangsrechnungen, Vorsteuerueberhang, Zahllast und optional Skonto-/Spaetkorrektur ab.
- Wenn eine Ziel-DB die neueren Zahlungsspalten nicht hat, laufen Deployment und Tests weiterhin; der Skonto-Test erkennt diese Schnittstellenluecke als dokumentierten Uebergangszustand.
