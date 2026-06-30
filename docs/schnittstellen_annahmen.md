# Schnittstellen und Annahmen

Stand: 2026-06-23

Dieses Dokument fasst die Annahmen ueber Partner-Schnittstellen und den
Konsum-Mechanismus des Umsatzsteuer-Moduls zusammen. Es enthaelt keine
Credentials und keine Connection Strings.

## Konsum-Prinzip

Gemaess ADR-008 berechnet Gruppe 15 keine Steuerbetraege selbst.
Wir konsumieren die nach HdM-Konvention vereinbarten Spalten direkt aus
den Partner-Lese-Views im Schema `list_views`.

| Quell-Gruppe | Inhalt | Erwartete Partner-View | Erwartetes Feld |
|---|---|---|---|
| G4 — Lieferantenrechnungen | Vorsteuer | `list_views.V_LIST_SUPPLIER_INVOICE` | `TOTAL_VAT_AMOUNT`, `INVOICE_ID`, `INVOICE_DATE` |
| G7 — alle Ausgangsrechnungen | Umsatzsteuer | `list_views.V_LIST_G07_INVOICE` | `BetragUstEUR` (heutiger Name) |
| G8 — Zahlungseingang | finaler Steuerbetrag (Skonto) | `list_views.V_LIST_G08_PAYMENT_RECEIPT` | `INVOICE_ID`, finaler Steuerbetrag (fehlt noch), `SKONTO_BERECHTIGT_YN` (Flag da) |

Steuerlich relevant ist das jeweilige Rechnungs- bzw. Belegdatum.
Status-Filter werden nicht angewendet — die Partner-View ist verantwortlich
dafuer, nur abgeschlossene und nicht stornierte Belege auszuliefern.

**Eine Quelle fuer alle Ausgangsrechnungen (Beschluss 2026-06-16):** G9
(Bar Rosenberg) und G10 (Bar Freiburg) schreiben ueber dieselbe
`dbo.T_INVOICE` wie G7 und werden kuenftig ueber `V_LIST_G07_INVOICE`
mitgeliefert. Es gibt deshalb keine eigenen G9/G10-Quellen mehr. Hintergrund:
`V_LIST_G07_INVOICE` ist ueber INNER JOINs auf die Fernabsatz-Kette
(Angebot -> Auftrag -> Lieferung) gebaut; B2C-Barverkaeufe ohne diese Kette
fallen aktuell heraus (Diagnose 2026-06-16: 78 von 156 G9-Rechnungen
sichtbar). G7 muss die View so erweitern, dass alle T_INVOICE-Ausgangs-
rechnungen erscheinen — bis dahin zaehlt nur Fernabsatz.

**Skonto (Beschluss 2026-06-16, ADR-010):** G8 liefert je Zahlungseingang
den *finalen* Steuerbetrag der Rechnung nach Skonto plus `IS_SKONTO` (Y/N),
keinen separaten Korrekturbetrag mehr. Wir ueberschreiben damit den
urspruenglichen `TAX_AMOUNT` der Rechnung (Match ueber `INVOICE_ID`). Bis G8
den finalen Steuerbetrag vollstaendig liefert, bleibt die automatische Skonto-
Beruecksichtigung deaktiviert; die App verlangt vor der Freigabe eine manuelle
Bestaetigung der Skonto- und Zahlungsdifferenzpruefung.

## Aktueller Lieferstand der Partner (Diagnose 2026-06-23 gegen ERPDEV26S)

| Partner | Status | Wirkung |
|---|---|---|
| G7 | View deployed, Spalten deutsch (`BetragUstEUR`, `RechnungsDatum`). Liefert aktuell nur Fernabsatz (INNER-JOIN-Kette), 83 von 161 G9-Rechnungen sichtbar. | AKTIV in `V_LIST_G15_OUTPUT_VAT`. Mapping deutsch -> englisch im SELECT. B2C noch nicht enthalten. |
| G9 / G10 | B2C-Views vorhanden, sollen aber ueber `V_LIST_G07_INVOICE` mitlaufen. | Keine eigene Quelle mehr; abhaengig von G7-View-Erweiterung. |
| G4 | View `V_LIST_SUPPLIER_INVOICE` seit 23.06. deployed (UPPER_SNAKE, mit `TOTAL_VAT_AMOUNT`), aber noch 0 Datenzeilen. | AKTIV in `V_LIST_G15_INPUT_VAT` (`TOTAL_VAT_AMOUNT -> TAX_AMOUNT`). Liefert Zeilen, sobald G4 Daten einspielt. |
| G8 | View deployed (`V_LIST_G08_PAYMENT_RECEIPT`); Skonto-Flag `SKONTO_BERECHTIGT_YN` seit 23.06. da, finaler Steuerbetrag nach Skonto fehlt noch. | STUB in `V_LIST_G15_VAT_SKONTO`. Aktivierung erst, wenn finaler Steuerbetrag geliefert wird. Bis dahin muss die Skonto-/Zahlungsdifferenzpruefung vor der Freigabe manuell bestaetigt werden. |

## Eigene Konsumenten-Views

- `list_views.V_LIST_G15_OUTPUT_VAT` — alle Ausgangsrechnungen aus G7
  (eine Quelle, kein UNION mehr).
- `list_views.V_LIST_G15_VAT_SKONTO` — finaler Steuerbetrag je Rechnung aus G8
  (Skonto). Wird in `sp_G15_create_vat_statement` zum Ueberschreiben genutzt
  (ADR-010). Aktuell Stub.
- `list_views.V_LIST_G15_INPUT_VAT` — Vorsteuer aus G4
  (`V_LIST_SUPPLIER_INVOICE`, AKTIV seit 23.06.; 0 Zeilen bis G4 Daten hat).
- `list_views.V_LIST_G15_VAT_STATEMENT`, `V_LIST_G15_VAT_STATEMENT_ITEM` — Anzeige-
  Views auf unsere eigenen Tabellen.
- `list_views.V_LIST_G15_VAT_USER` — Login + Rolle (kein Passwort).

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

- **G4** hat die Lese-View `list_views.V_LIST_SUPPLIER_INVOICE` mit
  `INVOICE_ID, INVOICE_DATE, TOTAL_VAT_AMOUNT` (UPPER_SNAKE) seit 23.06.
  geliefert (in `V_LIST_G15_INPUT_VAT` konsumiert). Offen nur noch: G4 muss
  Rechnungsdaten einspielen (View aktuell 0 Zeilen).
- **G7** muss `V_LIST_G07_INVOICE` so erweitern, dass **alle** Ausgangs-
  rechnungen aus `T_INVOICE` erscheinen — auch B2C-Barverkaeufe (G9/G10)
  ohne vollstaendige Angebot->Auftrag->Lieferung-Kette. Aktuell filtern die
  INNER JOINs diese heraus (Diagnose 2026-06-16: 78 von 156 G9-Rechnungen
  sichtbar). Mittelfristig zusaetzlich UPPER_SNAKE
  (`RechnungsDatum -> INVOICE_DATE`, `BetragUstEUR -> TAX_AMOUNT`);
  solange mappen wir im SELECT.
- **G8** hat in `V_LIST_G08_PAYMENT_RECEIPT` seit 23.06. das Skonto-Flag
  `SKONTO_BERECHTIGT_YN` (Y/N), aber noch keinen finalen Steuerbetrag nach
  Skonto. G8 muss diesen finalen Steuerbetrag je Zahlungseingang (Match ueber
  `INVOICE_ID`) ergaenzen, damit `V_LIST_G15_VAT_SKONTO` aktiviert werden kann
  (ADR-010). Bis dahin weist die App unmittelbar vor `DRAFT -> APPROVED` auf
  die manuelle Skonto-/Zahlungsdifferenzpruefung hin und laesst die Freigabe
  erst nach aktiver Bestaetigung zu.
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
