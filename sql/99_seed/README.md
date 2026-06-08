# Seed-Daten für die Sandbox

Hier liegen Testdaten, die wir in die eigene Sandbox-DB einspielen, um die Stored Procs/Functions gegen realistische Inhalte zu testen.

Aktuell enthalten:

- `001_demo_vat_workflow.sql` — Demo-Daten fuer April 2026 mit Zahllast, Maerz 2026 mit Vorsteuerueberhang und Februar 2026 als leerer Neutralfall.

Die Demo nutzt vorhandene Material- und User-Daten der Sandbox. Rollen werden aus `dbo.T_USER.SECURITYLEVEL` gelesen:

- `1` = Sachbearbeiter
- `3` = CFO
- `2` = Leitung FiBu

Abgedeckte Inhalte:

- Einige `T_INVOICE`-, `T_INVOICE_ITEM`- und `T_MATERIAL`-Zeilen (Ausgangsrechnungen); Umsatzsteuer wird aktuell aus `QUANTITY * SALES_PRICE * VAT / 100` aggregiert
- Einige `T_SUPPLIER_INVOICE`- und `T_SUPPLIER_INVOICE_ITEM`-Zeilen (Eingangsrechnungen); Vorsteuer wird aktuell aus Item-Werten und `UNIT_VAT_PCT` aggregiert
- Optionale Zahlungskorrekturen aus `T_PAYMENT_RECEIPT`, wenn die Ziel-DB die benoetigten Skonto-/Storno-Spalten besitzt
- Edge Cases: leerer Monat, nur USt, nur VSt, gemischt, exakt ausgeglichen

Der Dev-DB-Snapshot aus `99_devdb_kopie/` darf lokal als Referenz dienen, wird aber nicht committed.
