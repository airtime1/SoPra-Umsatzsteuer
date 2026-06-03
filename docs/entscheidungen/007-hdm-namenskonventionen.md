# ADR-007: Anpassung an HdM-Namenskonventionen (Lerneinheit 7)

- **Status:** akzeptiert
- **Datum:** 2026-06-03
- **Ablöst:** Teile von ADR-003 (Spaltennamen) — nur insoweit dass das Schema-Mapping HdM-konform wird, die fachlichen Festlegungen (VAT_STATUS, SOURCE_INVOICE_DATE) bleiben gleich.

## Kontext

Lerneinheit 7 (`docs/namenskonventionen/Lerneinheit_7_Datenbankentwicklung.docx`) und die Dev-DB-Kopie (`sql/99_devdb_kopie/`) zeigen das verbindliche Naming-Schema der HdM. MS4 hatte abweichende Großschreibung verwendet (`SF_`, `SP_`, View-Schemas `lov_views`), was Konflikt mit den existierenden Konventionen erzeugt.

Bei Verstößen droht laut Vorgabe: „Objekte, die nicht den Namenskonventionen entsprechen, werden nach Warnung gelöscht."

## Entscheidung

1. **Stored Procedures und Functions in Kleinbuchstaben** mit Präfixen `sp_` / `fn_`.
2. **Parameter klein** (`@vat_period`, `@created_by`).
3. **View-Präfixe nach Funktion**: `LOV_` (Werteliste), `V_LIST_` (Anzeigen), `V_INS_` (Einfügen), `V_UPD_` (Ändern). Alle in `list_views` / `ins_views` / `upd_views` (LOV gehört in `list_views`).
4. **Tabellen und Tabellen-Spalten bleiben UPPER_CASE** — `dbo.T_VAT_STATEMENT.VAT_STATUS` etc. unverändert.
5. **View-Spalten-Aliase in CamelCase** bei Umbenennung. Wenn keine Umbenennung nötig: Original UPPER_CASE durchreichen.

## Konsequenzen

- Alle `sql/03_stored_func/`, `sql/04_stored_proc/`, `sql/02_views/`-Skripte umgeschrieben/umbenannt.
- Frontend (`app/services/vat.py`) ruft die neuen Namen auf.
- Tests in `tests/sql/` aktualisiert.
- `CLAUDE.md` reflektiert die korrigierten Namen.
- Bei zukünftigen Erweiterungen IMMER zuerst in der Dev-DB-Kopie nach Vorbildern suchen, bevor neue Patterns erfunden werden.

## Beobachtung in Dev-DB

Die bestehenden Views (`LOV_STATUS_FOLGE`, `V_LIST_BIKE_ORDERS_BOM` etc.) folgen dem Naming, **aber** verwenden bei View-Spalten überwiegend UPPER_CASE statt CamelCase. Die Doku ist hier strenger als die Praxis. Wir folgen der Doku-Vorgabe (CamelCase bei Umbenennung), pragmatisch jedoch durch UPPER_CASE-Durchreichen wo sinnvoll.
