# ADR-010: Skonto-Korrektur überschreibt finalen Steuerbetrag der Rechnung

- **Status:** akzeptiert
- **Datum:** 2026-06-16
- **Löst ab:** [ADR-005](005-korrekturen.md)

## Kontext

ADR-005 modellierte Korrekturen als eigene Item-Zeile (`IS_CORRECTION=1`,
negativer `TAX_AMOUNT`, `ORIGINAL_INVOICE_ID` zeigt auf die Ursprungs-
rechnung). Das setzte voraus, dass Gruppe 8 einen separaten
*Korrekturbetrag* (`TAX_CORRECTION_AMOUNT`) liefert, den wir hätten
gegenrechnen müssen.

Gruppe 8 hat die Schnittstelle nach Abstimmung (2026-06-16) geändert: In
der Liste der Zahlungseingänge liefert G8 künftig je Beleg eine
Rechnungsnummer (`INVOICE_ID`), den **finalen** Steuerbetrag der Rechnung
nach Skonto und ein Feld `IS_SKONTO` (Y/N). Damit ist kein
Korrekturbetrag mehr zu berechnen — der Endwert kommt fertig.

## Entscheidung

Die Skonto-Korrektur wird **nicht** als eigene Belegzeile gebucht, sondern
**überschreibt** den ursprünglichen `TAX_AMOUNT` der bereits erfassten
Rechnung. Verfahren in `stored_proc.sp_G15_create_vat_statement`:

1. **Erfassen:** Alle USt (`V_LIST_G15_OUTPUT_VAT`) und VSt
   (`V_LIST_G15_INPUT_VAT`) der Periode mit dem ursprünglichen Steuerbetrag
   als Items anlegen.
2. **Überschreiben:** Über `list_views.V_LIST_G15_VAT_SKONTO` (liest G8) die
   Rechnungen mit `IS_SKONTO = 'Y'` ermitteln und auf der passenden
   Item-Zeile (Match über `INVOICE_ID`) den finalen Steuerbetrag setzen,
   `IS_CORRECTION = 1` und `ORIGINAL_INVOICE_ID = SOURCE_INVOICE_ID`.

Damit bleibt ADR-008 gewahrt: G15 berechnet keine Steuer, sondern
konsumiert den fertigen Endbetrag.

## Periodensicherheit

Wir gewähren maximal **7 Tage Skonto**. Genau deshalb darf eine Periode
erst **ab dem 10. des Folgemonats** abgerechnet werden
(`fn_G15_check_vat_period`). Eine Rechnung der Periode kann spätestens 7 Tage
nach dem Monatsende mit Skonto bezahlt werden — also vor dem
Abrechnungsstichtag. Beim Bau der Abrechnung sind daher alle relevanten
Skonto-Zahlungen bereits eingegangen. Das Matching über `INVOICE_ID`
gegen die in der Periode erfassten Rechnungen erfasst sie vollständig;
ein gesonderter Datumsfilter auf die Zahlungseingänge ist nicht nötig.

## Konsequenzen

- `IS_CORRECTION` und `ORIGINAL_INVOICE_ID` in `T_VAT_STATEMENT_ITEM`
  bleiben erhalten (Audit-Spur: „hier hat Skonto gewirkt"), ohne Schema-
  Änderung an der Architekten-Tabelle.
- `V_LIST_G15_OUTPUT_VAT` führt **keinen** G8-Korrektur-Block mehr; G8 fließt
  nur noch über den Überschreib-Schritt ein.
- Neue View `list_views.V_LIST_G15_VAT_SKONTO` (vorerst Stub `WHERE 1 = 0`,
  bis G8 die Felder `INVOICE_ID` / finaler `TAX_AMOUNT` / `IS_SKONTO`
  liefert — Issue #26).
- Schnittstellen-Anforderung an G8 ist neu: finaler Steuerbetrag statt
  separatem Korrekturbetrag (`docs/schnittstellen_annahmen.md`).
- Annahme: je Rechnung höchstens ein Skonto-relevanter, nicht stornierter
  Zahlungseingang. Mehrfach-/Teilzahlungen mit Skonto sind aktuell nicht
  modelliert.
