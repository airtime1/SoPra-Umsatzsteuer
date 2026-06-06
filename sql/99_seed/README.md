# Seed-Daten für die Sandbox

Hier kommen Testdaten rein, die wir in die eigene Sandbox-DB einspielen, um die Stored Procs/Functions gegen realistische Inhalte zu testen.

Idealer Inhalt:
- Einige `T_INVOICE`-, `T_INVOICE_ITEM`- und `T_MATERIAL`-Zeilen (Ausgangsrechnungen); Umsatzsteuer wird aktuell aus `QUANTITY * SALES_PRICE * VAT / 100` aggregiert
- Einige `T_SUPPLIER_INVOICE`- und `T_SUPPLIER_INVOICE_ITEM`-Zeilen (Eingangsrechnungen); Vorsteuer wird aktuell aus Item-Werten und `UNIT_VAT_PCT` aggregiert
- Mindestens eine Korrektur-Rechnung (`IS_CORRECTION=1`)
- Edge Cases: leerer Monat, nur USt, nur VSt, gemischt, exakt ausgeglichen

Der Dev-DB-Snapshot aus `99_devdb_kopie/` darf lokal als Referenz dienen, wird aber nicht committed.
