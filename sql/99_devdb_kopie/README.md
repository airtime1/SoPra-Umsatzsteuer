# Kopie der Dev-Datenbank

Hierhin gehört die SQL-Kopie der HdM-Dev-DB (`ERPDEV26S`-Snapshot), die wir herunterladen können. Sie dient als Referenz für:
- vorhandene Tabellen anderer Gruppen (z. B. `T_INVOICE`, `T_SUPPLIER_INVOICE`)
- bestehende Stored Procs / Functions / Views
- aktuellen Stand der Schnittstellen-Spalten; Gruppe 7 liefert aktuell keine `T_INVOICE.TAX_AMOUNT`-Spalte, die Ausgangssteuer wird ueber `T_INVOICE_ITEM` und `T_MATERIAL` hergeleitet

**Status:** Ein Snapshot wurde ausgewertet; die Datei selbst wird wegen Größe nicht committed (siehe `.gitignore`) und nur lokal vorgehalten.

Wenn ein Agent mit Schnittstellen- oder Naming-Fragen arbeitet und lokal kein Snapshot vorhanden ist, nicht raten: vorhandene Doku (`docs/offene_fragen.md`, `docs/namenskonventionen/INDEX.md`, SQL-Kommentare) lesen und die fehlende Information als offene Frage bzw. GitHub Issue markieren.
