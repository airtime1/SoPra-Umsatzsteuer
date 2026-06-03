# Seed-Daten für die Sandbox

Hier kommen Testdaten rein, die wir in die eigene Sandbox-DB einspielen, um die Stored Procs/Functions gegen realistische Inhalte zu testen.

Idealer Inhalt:
- Einige `T_INVOICE`-Zeilen (Ausgangsrechnungen) mit `TAX_AMOUNT`, gemischt aus mehreren Monaten
- Einige `T_SUPPLIER_INVOICE`-Zeilen (Eingangsrechnungen) mit `TAX_AMOUNT`
- Mindestens eine Korrektur-Rechnung (`IS_CORRECTION=1`)
- Edge Cases: leerer Monat, nur USt, nur VSt, gemischt, exakt ausgeglichen

Sobald wir den Dev-DB-Snapshot aus `99_devdb_kopie/` haben, können wir uns Daten daraus klauen statt selbst zu erfinden.
