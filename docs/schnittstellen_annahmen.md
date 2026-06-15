# Schnittstellen und Annahmen

Stand: 2026-06-13

Dieses Dokument fasst die Annahmen ueber Partner-Schnittstellen und den
Konsum-Mechanismus des Umsatzsteuer-Moduls zusammen. Es enthaelt keine
Credentials und keine Connection Strings.

## Konsum-Prinzip

Gemaess ADR-008 berechnet Gruppe 15 keine Steuerbetraege selbst.
Wir konsumieren die nach HdM-Konvention vereinbarten Spalten direkt aus
den Partner-Lese-Views im Schema `list_views`.

| Quell-Gruppe | Inhalt | Erwartete Partner-View | Erwartetes Feld |
|---|---|---|---|
| G4 — Wareneingaenge | Vorsteuer | `list_views.V_LIST_G04_SUPPLIER_INVOICE` | `TAX_AMOUNT` |
| G7 — Rechnungen Fernabsatz | Umsatzsteuer | `list_views.V_LIST_G07_INVOICE` | `BetragUstEUR` (heutiger Name) |
| G9 — Barrechnung Rosenberg | Umsatzsteuer | `list_views.V_LIST_G09_INVOICE_TAX_B2C` | `TAX_AMOUNT` |
| G10 — Barrechnung Freiburg | Umsatzsteuer | `list_views.V_LIST_G10_INVOICE_*` (Name offen) | `TAX_AMOUNT` |
| G8 — Zahlungseingang | Skonto-Korrektur | `list_views.V_LIST_G08_PAYMENT_RECEIPT` | `TAX_CORRECTION_AMOUNT` (positiv) |

Steuerlich relevant ist das jeweilige Rechnungs- bzw. Belegdatum.
Status-Filter werden nicht angewendet — die Partner-View ist verantwortlich
dafuer, nur abgeschlossene und nicht stornierte Belege auszuliefern.

## Aktueller Lieferstand der Partner (Diagnose 2026-06-13 gegen ERPDEV26S)

| Partner | Status | Wirkung in unserem Bundle |
|---|---|---|
| G7 | View deployed, Spalten deutsch (`BetragUstEUR`, `RechnungsDatum`). | AKTIV in `V_LIST_OUTPUT_VAT`. Mapping deutsch -> englisch erfolgt im SELECT. |
| G9 | View deployed (`V_LIST_G09_INVOICE_TAX_B2C`), `TAX_AMOUNT` fehlt. | STUB in `V_LIST_OUTPUT_VAT`. Aktivierung nach Lieferung. |
| G10 | Keine `V_LIST_G10_*`-View vorhanden. | STUB in `V_LIST_OUTPUT_VAT`. Aktivierung nach Lieferung. |
| G4 | Keine `V_LIST_G04_*`-View vorhanden. | STUB in `V_LIST_INPUT_VAT`. Aktivierung nach Lieferung. |
| G8 | View deployed (`V_LIST_G08_PAYMENT_RECEIPT`), `TAX_CORRECTION_AMOUNT` fehlt. | STUB in `V_LIST_OUTPUT_VAT`. Aktivierung nach Lieferung. |

## Eigene Konsumenten-Views

- `list_views.V_LIST_OUTPUT_VAT` — Ausgangsrechnungen + Skonto-Korrekturen
  als UNION ALL aus G7, G9, G10 und G8. Aktive und Stub-Quellen siehe oben.
- `list_views.V_LIST_INPUT_VAT` — Vorsteuer aus G4 (aktuell Stub).
- `list_views.V_LIST_VAT_STATEMENT`, `V_LIST_VAT_STATEMENT_ITEM` — Anzeige-
  Views auf unsere eigenen Tabellen.
- `list_views.V_LIST_VAT_USER` — Login + Rolle (kein Passwort).

## Stub-Pattern (technisch)

Ein Stub-Block hat dieselbe Spaltensignatur wie der spaetere echte SELECT,
aber `WHERE 1 = 0`. Beispiel:

```sql
SELECT
    CAST('T_INVOICE' AS VARCHAR(50))   AS SOURCE_TABLE,
    CAST(NULL AS INT)                  AS SOURCE_INVOICE_ID,
    CAST(NULL AS DATE)                 AS SOURCE_INVOICE_DATE,
    CAST(NULL AS INT)                  AS INVOICE_ID,
    CAST(NULL AS DATE)                 AS INVOICE_DATE,
    CAST(NULL AS DECIMAL(12,2))        AS TAX_AMOUNT,
    CAST(0 AS BIT)                     AS IS_CORRECTION,
    CAST(NULL AS INT)                  AS ORIGINAL_INVOICE_ID
WHERE 1 = 0
```

`CAST(NULL AS <Typ>)` fixiert den Datentyp jeder Spalte, damit das UNION ALL
auch ohne echte Zeilen valide ist und die Folgeprozeduren die Signatur
zuverlaessig erhalten. Der `WHERE 1 = 0`-Filter sorgt dafuer, dass der Stub
in jeder Abrechnung null Zeilen beisteuert. Bei Aktivierung wird der Stub-
Block durch den im Kommentar bereitgestellten echten SELECT ersetzt.

## Offene Punkte / Bring-Schulden

- **G4** muss eine Lese-View `list_views.V_LIST_G04_SUPPLIER_INVOICE` mit
  Spalten `INVOICE_ID, INVOICE_DATE, TAX_AMOUNT` (UPPER_SNAKE, HdM-Konvention)
  bereitstellen.
- **G7** sollte mittelfristig auf UPPER_SNAKE umstellen
  (`RechnungsDatum -> INVOICE_DATE`, `BetragUstEUR -> TAX_AMOUNT`).
  Solange wir mappen wir im SELECT.
- **G9** muss in `V_LIST_G09_INVOICE_TAX_B2C` die Spalte `TAX_AMOUNT`
  ergaenzen (kein Brutto, kein Anteil).
- **G10** muss eine Lese-View bereitstellen, Name analog zu G9.
- **G8** muss in `V_LIST_G08_PAYMENT_RECEIPT` die Spalte
  `TAX_CORRECTION_AMOUNT` (Steueranteil der Skonto-Korrektur, positiv)
  ergaenzen.
- **Architekt** (Lehmann) muss
  `MS5_G15_ARCHITEKT_dbo.sql` ausfuehren: T_CODE-Eintraege fuer VAT_STATUS,
  T_CODE_NEXT-Eintraege fuer die Uebergaenge und die Tabellen
  T_VAT_STATEMENT / T_VAT_STATEMENT_ITEM.

## Abhaengigkeit auf zentrale Architekten-Objekte

Die Status-Procedures rufen die zentrale Function
`dbo.fn_chk_status_folge(@status_alt, @status_neu)` auf, um Statusuebergaenge
gegen `dbo.T_CODE_NEXT` zu pruefen (siehe ADR-009). Diese Function ist in
ERPDEV26S vorhanden. In der lokalen Sandbox fehlt sie; ein vollstaendiger
Status-Workflow-Test ist daher nur gegen ERPDEV26S moeglich.
