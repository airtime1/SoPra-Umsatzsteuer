# Offene Fragen

Punkte, die wir extern klären müssen — ans Team, an Prof. Meth / Lehmann, oder an Partner-Gruppen.

Format: `[Status] Frage — Adressat — Datum erstellt`. Status ∈ {OFFEN, GEKLÄRT, OBSOLET}.

## Architektur & Datenbank

- [OFFEN] In welchem Schema werden unsere Tabellen `T_VAT_STATEMENT` und `T_VAT_STATEMENT_ITEM` angelegt? `dbo` ist gesperrt, aber kein eigenes Schema für Tabellen erwähnt — gehen die ans `dbo`-Architekt-Schema? — Architekt (Peter Lehmann)
- [OFFEN] Wie ist der konkrete Prozess zur Anlage von Tabellen / T_CODE-Einträgen? Skript per Mail an den Architekt? Pull-Request? — Architekt
- [OFFEN] Brauchen wir `ins_views` / `upd_views` für jeden Schreibvorgang aus dem Frontend, oder darf `ERP_REMOTE_USER` direkt auf Tabellen schreiben? — Architekt
- [OFFEN] Wo finden wir das Dokument mit den HdM-Namenskonventionen? — User reicht nach in `docs/namenskonventionen/`
- [OFFEN] SQL-Dump der Dev-DB (ERPDEV26S-Snapshot) — User reicht nach in `sql/99_devdb_kopie/`

## Schnittstellen zu anderen Gruppen

- [OFFEN] Gruppe 4 (Eingangsrechnungen): Wann ergänzt sie `TAX_AMOUNT` in `T_SUPPLIER_INVOICE`? Wie wird Korrekturlogik dort abgebildet?
- [OFFEN] Gruppe 7 (Ausgangsrechnungen): Wann ergänzt sie `TAX_AMOUNT`, `IS_CORRECTION`, `ORIGINAL_INVOICE_ID` in `T_INVOICE`? Form der Korrekturzeile?
- [OFFEN] Gruppe 8 (Zahlungen / Skonto): Liefern sie Skonto als eigene Korrektur-Rechnung, oder mutieren sie die Ursprungsrechnung?
- [OFFEN] Gruppen 9/10 (Barrechnung Freiburg/Rosenberg): Liefern Daten direkt in `T_INVOICE` oder eigene Tabellen?
- [OFFEN] Gruppe 19 (FiBu) ist unbesetzt — bestätigen, dass wir nur theoretisch ausgeben und keinen abnehmenden Konsumenten haben

## Fachlich

- [OFFEN] Behandlung leerer Perioden (F17): erzeugen wir eine leere Abrechnung mit Hinweis, oder verweigern wir den Anlage-Versuch?
- [OFFEN] Mehrere Steuersätze (Anforderung D): bauen wir vereinfacht mit 19% Fixwert, oder vorbereitend per Steuercode?
- [OFFEN] Wer prüft die zeitliche Cut-off-Logik aus Sicht der Steuerlogik — ist das wirklich nur "Tag ≥ 10"? Was passiert mit Belegen, die nach dem 10. noch nachgeliefert werden?

## Team-intern

- [OFFEN] Finale Frontend-Entscheidung: Python (vorläufig) vs. phpRunner — Stichtag für Wechsel-Option?
- [OFFEN] Repo-Host: GitHub privat, HdM-Gitlab, oder lokal?
- [OFFEN] Aufgabenteilung MS5: Wer baut welchen Teil (SQL / Frontend / Tests / Doku)?
