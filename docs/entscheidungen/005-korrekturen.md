# ADR-005: Korrekturen als eigene Item-Zeile mit negativem Betrag

- **Status:** abgeloest durch [ADR-010](010-skonto-ueberschreiben.md) (2026-06-16)
- **Datum:** 2026-06-03

> **Hinweis:** Diese Entscheidung gilt nicht mehr. Gruppe 8 liefert je
> Zahlungseingang den *finalen* Steuerbetrag der Rechnung; die Skonto-
> Korrektur ueberschreibt seither den urspruenglichen `TAX_AMOUNT` der
> Rechnung, statt als eigene Belegzeile gefuehrt zu werden. Begruendung
> und neues Verfahren in [ADR-010](010-skonto-ueberschreiben.md).

## Kontext

MS3-Beispiel zeigt Korrekturen als eigene Zeile (`K1235 -6,70` neben `R1235`). MS4-Tabellenmodell ist uneindeutig: `IS_CORRECTION` und `ORIGINAL_INVOICE_ID` sind sowohl in den ergänzten Spalten von `T_INVOICE` (Gruppe 7) als auch in `T_VAT_STATEMENT_ITEM` modelliert.

## Optionen

1. **Spalte auf Ursprungsrechnung**: Korrektur mindert direkt den `TAX_AMOUNT` der ursprünglichen Rechnung in `T_INVOICE`. Vorteil: weniger Zeilen. Nachteil: Historie der Korrektur geht verloren, doppelte Berechnung wird schwerer auszuschließen.
2. **Eigene Zeile in `T_VAT_STATEMENT_ITEM`** mit `IS_CORRECTION=1`, negativer `TAX_AMOUNT`, `ORIGINAL_INVOICE_ID` zeigt auf Ursprung. Vorteil: vollständige Audit-Spur. Nachteil: mehr Zeilen pro Periode.

## Entscheidung

**Option 2.**

Begründung:
- Revisionssichere Historisierung (F15) verlangt Nachvollziehbarkeit: Wer hat wann welche Korrektur eingebracht? Die eigene Zeile lässt sich timestampen und auditieren.
- `SUM(TAX_AMOUNT) WHERE VAT_STATEMENT_ID = X` liefert direkt das korrekte Periodenergebnis ohne Sonderlogik.
- Die mengenmäßige "Mehr-Zeilen"-Sorge ist irrelevant — die Anzahl Korrekturen pro Periode bleibt klein.

## Konsequenzen

- Schnittstellen-Anforderung an Gruppen 4/7/8: Korrekturen werden als separate Belegzeilen geliefert, nicht durch Mutation der Ursprungsrechnung. (Dies muss mit den Gruppen abgestimmt werden — siehe `docs/offene_fragen.md`.)
- `T_VAT_STATEMENT_ITEM`-Skript: `IS_CORRECTION BIT NOT NULL DEFAULT 0`, `ORIGINAL_INVOICE_ID INT NULL` (nullable, weil Originalrechnungen keine Referenz haben).
- Constraint-Idee: Wenn `IS_CORRECTION = 1`, muss `ORIGINAL_INVOICE_ID IS NOT NULL`.
- In `stored_proc.sp_G15_create_vat_statement` muss die Logik beide Quellen (Original-Rechnungen + Korrekturen) in derselben Periode einsammeln.
