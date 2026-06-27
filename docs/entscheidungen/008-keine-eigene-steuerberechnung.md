# ADR-008 — Gruppe 15 berechnet keine Steuerbetraege

Status: Akzeptiert
Datum: 2026-06-13

## Kontext

Mehrere Partner-Gruppen erzeugen Geschaeftsvorfaelle, die fuer die monatliche
Umsatzsteuerabrechnung relevant sind:

- Gruppe 7 (Rechnungen Fernabsatz) — Umsatzsteuer
- Gruppe 9 (Barrechnung Rosenberg) — Umsatzsteuer
- Gruppe 10 (Barrechnung Freiburg) — Umsatzsteuer
- Gruppe 4 (Wareneingaenge) — Vorsteuer
- Gruppe 8 (Zahlungseingaenge) — Umsatzsteuer-Korrektur (Skonto)

In einer fruehen Implementierungsphase haben wir in `V_LIST_G15_OUTPUT_VAT` und
`V_LIST_G15_INPUT_VAT` versucht, Steuerbetraege selbst zu berechnen, indem wir aus
`T_INVOICE_ITEM`, `T_SUPPLIER_INVOICE_ITEM` und `T_MATERIAL` mit COALESCE-
Kaskaden und Dynamic-SQL einen Steuerbetrag rekonstruiert haben. Beim Skonto
haben wir den Steueranteil aus `DIFFERENCE_AMOUNT × (TAX/GROSS)` proportional
abgeleitet.

Bei der Abstimmung im Team-Setup wurde klar: Diese Rechnungslogik ist nicht
unsere Verantwortung. Jede Partner-Gruppe haftet fuer ihre eigenen Steuer-
beziehungsweise Steuerkorrekturbetraege. Gruppe 15 ist Konsument, nicht
Erzeuger.

## Entscheidung

1. **Gruppe 15 berechnet keine Steuerbetraege.** Weder
   `V_LIST_G15_OUTPUT_VAT` noch `V_LIST_G15_INPUT_VAT` enthalten Berechnungslogik,
   die einen Steuerbetrag aus Mengen, Preisen oder Prozentsaetzen ableitet.

2. **Wir konsumieren Partner-Lese-Views.** Quelle der Werte ist immer eine
   Partner-View im Schema `list_views`. Wir lesen die nach Konvention
   vereinbarten Spalten direkt:

   - `TAX_AMOUNT` von G4 (Vorsteuer) und G7 (Umsatzsteuer aller Ausgangs-
     rechnungen; G9/G10 laufen ueber dieselbe View, Beschluss 2026-06-16)
   - finaler `TAX_AMOUNT` nach Skonto von G8 (ueberschreibt den Rechnungs-
     betrag, siehe ADR-010 — loest die fruehere `TAX_CORRECTION_AMOUNT`-
     Negierung ab)

3. **Fehlende Partner-Felder oder fehlende Partner-Views ergeben keinen
   Workaround und keinen Fallback.** Die Bring-Schuld liegt bei der jeweiligen
   Partner-Gruppe. Wir dokumentieren die Luecke in einem GitHub-Issue an die
   Partner-Gruppe.

4. **Damit das Bundle trotzdem deploybar bleibt** waehrend die anderen
   Gruppen noch implementieren, verwenden wir das Stub-Pattern:
   Der UNION-ALL-Branch einer noch nicht lieferfaehigen Quelle liefert
   Spalten mit korrekter Signatur, aber 0 Zeilen (`WHERE 1 = 0`). Der
   spaetere Aktivierungs-SELECT steht im View-File als Kommentar bereit
   und wird ohne weitere Aenderungen ausgetauscht, sobald die Partner-Gruppe
   geliefert hat.

5. **Status-Filter auf Partner-Daten entfaellt.** Steuerlich entscheidend ist
   das Rechnungsdatum, nicht der Workflow-Status. Wenn eine Partner-View auch
   Entwuerfe oder Stornos liefert, ist das deren Filter-Verantwortung.
   Storno wird ueber eigene Buchungen (negative Rechnung) abgebildet, nicht
   ueber einen Status-Filter.

6. **`SOURCE_TABLE` in `T_VAT_STATEMENT_ITEM` bleibt eine fachliche
   Kategorie**, kein woertlicher View-Name:

   | Wert | Kategorie |
   |---|---|
   | `T_INVOICE` | Ausgangsrechnung (G7, G9, G10) |
   | `T_SUPPLIER_INVOICE` | Eingangsrechnung (G4) |
   | `T_PAYMENT_RECEIPT` | Skonto-Korrektur (G8) |

   Damit ist die bestehende `CHK_VAT_ITEM_SOURCE_TABLE`-Constraint kompatibel
   und Quell-Renaming durch Partner-Gruppen ist robust abgefangen.

## Konsequenzen

Positiv:
- Klare Verantwortungsteilung — die Partner-Gruppe haftet fuer ihre Werte.
- Sehr kurze, lesbare Views ohne Item-Aggregation und ohne Material-Fallback.
- Re-Aktivierung von Stub-Quellen ist ein 8-zeiliger Code-Swap, keine Logik-Aenderung.
- Pruefbar fuer den Dozenten: `SELECT * FROM list_views.V_LIST_G15_OUTPUT_VAT` zeigt
  sofort, welche Quellen aktiv und welche Stub sind.

Negativ:
- Solange Stubs aktiv sind, sind die zugehoerigen Werte in der Abrechnung 0,
  obwohl fachlich Belege vorliegen. Das ist transparent dokumentiert.
- Pflegeaufwand: Wir muessen die Stub-Aktivierung nach jeder Partner-Lieferung
  selbst nachziehen.

## Verbindung zu anderen ADRs

- Korrigiert ADR-007 / `docs/schnittstellen_annahmen.md`: dort stand zuvor,
  dass wir aus Items aggregieren, solange keine Kopf-`TAX_AMOUNT` existiert.
  Diese Annahme gilt nicht mehr.
- ADR-005 (Korrekturen als eigene Item-Zeilen) bleibt unveraendert.

## Aktivierungs-Vermerk

Aktueller Stand der Stubs (2026-06-16; G9/G10 und das G8-Skonto-Verfahren
durch den Beschluss 2026-06-16 / ADR-010 angepasst):

| Quelle | Erwartete Partner-View | Erwartete Spalte |
|---|---|---|
| G4 | `list_views.V_LIST_G04_SUPPLIER_INVOICE` | `TAX_AMOUNT` |
| G7 (inkl. G9/G10) | `list_views.V_LIST_G07_INVOICE` | `TAX_AMOUNT` (alle Ausgangsrechnungen) |
| G8 | `list_views.V_LIST_G08_PAYMENT_RECEIPT` | `INVOICE_ID`, finaler `TAX_AMOUNT`, `IS_SKONTO` (ADR-010) |
