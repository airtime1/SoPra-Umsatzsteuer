# ADR-004: Saldo als Absolutbetrag + getrennter Typ

- **Status:** akzeptiert
- **Datum:** 2026-06-03

## Kontext

MS3-Beispiel "Januar 2026" zeigt `Zahllast/überhang = -95,-` (negativer Wert = Überhang). MS4 `SF_CAL_VAT` rechnet `OUTPUT_VAT_TOTAL - INPUT_VAT_TOTAL = VAT_BALANCE`, würde also bei mehr Vorsteuer einen negativen Wert liefern. Die Testcases im MS4 zeigen aber `VAT_BALANCE = 100, TYPE = Überhang` (positiv + Label) — das ist inkonsistent mit der Logikbeschreibung.

## Optionen

1. **VAT_BALANCE vorzeichenbehaftet** (+ = Zahllast, − = Überhang), `VAT_TYPE` redundant ableitbar.
2. **VAT_BALANCE als Absolutbetrag (≥0)**, `VAT_TYPE ∈ {ZAHLLAST, UEBERHANG, NEUTRAL}` als verpflichtende Klassifikation.

## Entscheidung

**Option 2.**

Begründung:
- Auf dem Abrechnungsbeleg ans Finanzamt steht immer ein positiver Betrag mit Klassifikation ("Forderung X €" oder "Verbindlichkeit X €"). Keine Vorzeichen-Akrobatik in der UI.
- Verhindert subtile Bugs in Summen-Aggregationen, wo Vorzeichen schnell verloren gehen.
- `VAT_TYPE = NEUTRAL` deckt den Fall `OUTPUT = INPUT` sauber ab.

## Konsequenzen

- `stored_func.fn_G15_calculate_vat_balance` muss intern signed rechnen, dann am Ende `ABS()` + Typ-Mapping anwenden:
  - `output - input > 0` → `TYPE = 'ZAHLLAST'`, `BALANCE = output - input`
  - `output - input < 0` → `TYPE = 'UEBERHANG'`, `BALANCE = input - output`
  - `output - input = 0` → `TYPE = 'NEUTRAL'`, `BALANCE = 0`
- DB-Constraint: `CHECK (VAT_BALANCE >= 0)`.
- DB-Constraint: `CHECK (VAT_TYPE IN ('ZAHLLAST', 'UEBERHANG', 'NEUTRAL'))`.
