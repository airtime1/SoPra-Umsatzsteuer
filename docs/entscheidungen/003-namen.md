# ADR-003: Spaltennamen — `VAT_STATUS` und `SOURCE_INVOICE_DATE`

- **Status:** akzeptiert
- **Datum:** 2026-06-03

## Kontext

MS4 widerspricht sich selbst:
- Beschreibungstabelle `T_VAT_STATEMENT`: Spalte heißt `VAT_STATUS`. CREATE-TABLE-Skript: `STATUS`.
- Beschreibungstabelle `T_VAT_STATEMENT_ITEM`: Spalte heißt `SOURCE_INVOICE_DATE`. CREATE-TABLE-Skript: `INVOICE_DATE`.

## Entscheidung

- **`VAT_STATUS`** statt `STATUS`.
- **`SOURCE_INVOICE_DATE`** statt `INVOICE_DATE` in `T_VAT_STATEMENT_ITEM`.

Begründung:
- `STATUS` ist zu generisch und kollidiert in JOINs leicht mit anderen Status-Spalten anderer Module (z. B. `INVOICE_STATUS`).
- `INVOICE_DATE` als Spalte in einer Tabelle, die nicht selbst eine Rechnung ist, ist irreführend. `SOURCE_INVOICE_DATE` macht den Bezug zum Quellbeleg explizit, konsistent zu `SOURCE_TABLE` und `SOURCE_INVOICE_ID`.

## Konsequenzen

- Korrigierte Skripte in `sql/01_tables/`.
- Frontend-Code referenziert die korrigierten Namen.
- Falls in späteren MS-Dokumenten die alten Namen auftauchen, hier nachschauen.
