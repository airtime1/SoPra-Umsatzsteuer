# Projekt-Kontext für Claude — SoPra Umsatzsteuerabrechnung

> Briefing-Datei für Claude (und andere KI-Agents). Wird automatisch geladen, wenn Claude in diesem Verzeichnis arbeitet. Wenn sich Tech-Stack, Team oder Konventionen ändern, hier zuerst pflegen — alle Agents lesen es beim Start.

> **Dies ist ein Team-Repo auf GitHub.** Vor jeder Codeänderung bitte einmal `CONTRIBUTING.md` lesen (Branch-/Commit-/PR-Konventionen). Niemals direkt auf `main` pushen, keine Force-Pushes, keine Credentials committen.

## Wer arbeitet hier woran

- **Nutzer:** Nils Bachmann, Wi7 4. Semester, HdM Stuttgart, SoSe 2026
- **Kurs:** SoPra (Software-Praktikum) — ERP-Projekt im Konzern-ERP "Adventure Bike"
- **Gruppe:** 15 (an manchen Stellen historisch noch als 16 referenziert)
- **Modul:** Umsatzsteuerabrechnung
- **Team:** 3 Personen — Nils Bachmann, Moritz Jahnke, Abel Adonai Mesfine. Keine fixen Rollen (Full-Stack + PM).
- **Kommunikation:** WhatsApp "Fiskal aut morere", Miroboard, wöchentliches Treffen Montag HdM

## Was wir bauen

Modul, das aus Ein- und Ausgangsrechnungen je Abrechnungsmonat eine **Umsatzsteuerabrechnung** erstellt — Vorsteuer und Umsatzsteuer aggregieren, Saldo (Zahllast oder Überhang) berechnen, Status-Workflow (DRAFT → APPROVED → PAID), revisionssichere Historisierung, Beleg erzeugen.

**Wir bauen NICHT:** Rechnungen, Rechnungskorrekturen, Steuerbetragsberechnung pro Rechnung, elektronische Übermittlung ans Finanzamt, vollständige FiBu.

## Phase (Stand 2026-06-03)

| Phase | Status | Deadline (laut MS1 Gantt) |
|---|---|---|
| MS1 Projektplan | ✅ | März 2026 |
| MS2 Anforderungsanalyse | ✅ | März 2026 |
| MS3 Fachkonzept | ✅ | April 2026 |
| MS4 Systemkonzept | ✅ | April 2026 |
| **MS5 Implementierung + Test/Abnahmekonzept** | 🔜 IN ARBEIT | Mai 2026 |
| Integrationstest | offen | Juni 2026 |
| Test fremder Gruppen | offen | Juni 2026 |
| Fine Tuning + Golive | offen | Juli 2026 |

## Tech-Stack

- **Datenbank:** MS SQL Server (gestellt von HdM)
- **Frontend:** Python + Streamlit + pyodbc — **vorläufige Entscheidung**, Option auf späteren Wechsel zu phpRunner bleibt offen (deshalb so viel Logik wie möglich in Stored Procs/Functions, Frontend dünn halten)
- **Tests:** pytest gegen Sandbox-DB für SP/SF, manuelle UI-Tests
- **Versionierung:** Git lokal, Repo-Host vom Team noch zu entscheiden

## Datenbank-Zugriff

Drei Datenbanken, drei User. Echte Credentials in `.env` (nicht committen!), Template in `.env.example`.

| Zweck | Server | DB | User |
|---|---|---|---|
| Gemeinsame Entwicklung | `edu.hdm-server.eu` | `ERPDEV26S` | `s26s5xx` (persönlich) |
| Eigene Sandbox | `edu.hdm-server.eu` | `s26s5xx_DATAMART` | `s26s5xx` (persönlich) |
| Frontend-Zugriff | `edu.hdm-server.eu` | `ERPDEV26S` | `ERP_REMOTE_USER` (read/write/execute) |

## Datenbank-Schemata (ERPDEV26S)

Nur in den folgenden Schemata dürfen WIR Objekte anlegen:

| Schema | Wofür |
|---|---|
| `ins_views` | INSERT-Views (Wrapper für Frontend, das nicht direkt auf Tabellen schreiben darf) |
| `upd_views` | UPDATE-Views |
| `list_views` | Lese-Views (Listen, LOVs) |
| `stored_func` | Stored Functions |
| `stored_proc` | Stored Procedures |

**`dbo`-Schema ist gesperrt** — nur der Architekt (Peter Lehmann) kann dort Tabellen, `T_CODE`-Einträge etc. anlegen. Wir liefern Skripte aus `sql/00_setup/` und `sql/01_tables/` an ihn zur Anlage.

**Wichtig:** Objekte, die nicht den HdM-Namenskonventionen entsprechen, werden nach Warnung gelöscht. Konventionen liegen in `docs/namenskonventionen/`.

## Projekt-Struktur

```
SoPra-Umsatzsteuer/
├── CLAUDE.md                # diese Datei
├── README.md                # Setup + Quickstart
├── .env.example             # Template für DB-Credentials
├── .gitignore
├── requirements.txt         # Python-Dependencies
├── docs/
│   ├── konzepte/            # MS1–MS4 PDFs (Referenz, nicht editieren)
│   ├── namenskonventionen/  # HdM-Vorgabe
│   ├── entscheidungen/      # ADRs: warum welche Konvention/Architektur
│   ├── inkonsistenzen.md    # MS3/MS4-Konflikte + getroffene Auflösung
│   └── offene_fragen.md     # ans Team / Prof. / Architekt
├── sql/
│   ├── 00_setup/            # T_CODE-Inserts (an Architekt liefern)
│   ├── 01_tables/           # CREATE TABLE (an Architekt liefern)
│   ├── 02_views/            # list_views.*
│   ├── 03_stored_func/      # stored_func.SF_*
│   ├── 04_stored_proc/      # stored_proc.SP_*
│   ├── 05_ins_upd_views/    # ins_views.* / upd_views.* fürs Frontend
│   ├── 99_seed/             # Testdaten für Sandbox
│   └── 99_devdb_kopie/      # Kopie der Dev-DB von HdM (Referenz)
├── app/                     # Streamlit-Frontend
│   ├── main.py              # Einstiegspunkt
│   ├── db.py                # pyodbc-Wrapper, SP/SF-Calls
│   ├── pages/               # Streamlit Multi-Page-App
│   └── services/            # dünne Business-Logik (nicht in DB)
├── tests/
│   ├── sql/                 # SQL-Testskripte gegen Sandbox
│   ├── test_cases.md        # MS5: Testfall-Katalog
│   └── abnahmekriterien.md  # SPC-1..6 ausformuliert
└── scripts/
    ├── deploy_dev.py        # SQL-Skripte auf ERPDEV26S deployen
    └── deploy_sandbox.py    # Skripte auf eigene Sandbox deployen
```

## Verbindliche Konventionen aus dem Case

1. **`dbo` ist tabu** — Tabellen und `T_CODE`-Einträge nur per Skript an Architekt liefern.
2. **Logik gehört in die DB** — Frontend bleibt dünn (Wechsel-Option phpRunner).
3. **Namenskonventionen einhalten** — sonst Löschung nach Warnung.
4. **Abrechnungszeitraum = ein Kalendermonat**, frühestens am 10. des Folgemonats abrechnen (Skonto-Frist).
5. **Abgeschlossene Abrechnung unveränderlich** — Korrekturen wandern in die nächste offene Periode.

## Konventionen, die WIR getroffen haben

Siehe `docs/entscheidungen/` für vollständige ADRs.

| Thema | Entscheidung | ADR |
|---|---|---|
| Status-Modell | 3 Status englisch: `DRAFT` → `APPROVED` → `PAID` (+ Rückgabe `APPROVED` → `DRAFT`) | 001 |
| Rollen | Stufe 1 Sachbearbeiter (anlegen), Stufe 2 Leitung FiBu (auszahlen), Stufe 3 CFO (freigeben) | 002 |
| Statusspalte | `VAT_STATUS` (nicht `STATUS`) | 003 |
| Belegdatum-Spalte | `SOURCE_INVOICE_DATE` (nicht `INVOICE_DATE`) | 003 |
| Saldo-Speicherung | `VAT_BALANCE` als Absolutbetrag (≥0), `VAT_TYPE` ∈ {`ZAHLLAST`, `UEBERHANG`, `NEUTRAL`} | 004 |
| Korrekturen | Eigene Zeile in `T_VAT_STATEMENT_ITEM` mit `IS_CORRECTION=1`, `ORIGINAL_INVOICE_ID` zeigt auf Ursprung, negativer `TAX_AMOUNT` | 005 |
| Frontend-Stack | Python + Streamlit + pyodbc, Option auf phpRunner-Wechsel offen | 006 |
| Naming | HdM-Konvention strikt: `sp_`/`fn_` klein, `V_LIST_`/`LOV_`/`V_INS_`/`V_UPD_` für Views, Tabellen + Tabellenspalten UPPER_CASE, Parameter klein (`@vat_period`) | 007 |

## HdM-Namen unserer Objekte (siehe docs/namenskonventionen/)

| Objekt | Voller Name |
|---|---|
| Kopftabelle | `dbo.T_VAT_STATEMENT` |
| Detailtabelle | `dbo.T_VAT_STATEMENT_ITEM` |
| Werteliste Status | `list_views.LOV_VAT_STATUS` |
| Liste USt | `list_views.V_LIST_OUTPUT_VAT` |
| Liste VSt | `list_views.V_LIST_INPUT_VAT` |
| Periodencheck | `stored_func.fn_check_vat_period` |
| Saldoberechnung | `stored_func.fn_calculate_vat_balance` |
| Anlegen / Neu berechnen | `stored_proc.sp_create_vat_statement` |
| Freigeben (DRAFT → APPROVED) | `stored_proc.sp_approve_vat_statement` |
| Auszahlen (APPROVED → PAID) | `stored_proc.sp_pay_vat_statement` |
| Zurückweisen (APPROVED → DRAFT) | `stored_proc.sp_reject_vat_statement` |

## Wenn Claude unsicher ist…

- **Vorher fragen**, wenn:
  - Etwas potenziell gegen Case-Regeln verstößt (z. B. `dbo` direkt anfassen)
  - Konventionen unklar sind und kein ADR existiert
  - Schnittstelle zu anderer Gruppe betroffen ist (wir können nicht einseitig ändern)
- **Einfach machen**, wenn:
  - SQL-Skripte refactorn / kommentieren
  - Streamlit-UI-Polish ohne Logikänderung
  - Test-Templates schreiben
  - Dokumentation aktualisieren

## Was Claude NICHT tun darf

- Niemals `.env`-Datei committen oder in Logs ausgeben
- Niemals direkt auf `ERPDEV26S` deployen ohne Bestätigung (Bypass-Tests gehen erst auf Sandbox)
- Niemals `dbo`-Objekte verändern (geht ohnehin nicht mit unseren Rechten, aber: Skripte als "an Architekt liefern" kennzeichnen)
- Niemals Inhalt von Schnittstellen-Tabellen (`T_INVOICE`, `T_SUPPLIER_INVOICE`) löschen oder umbauen — wir lesen nur
- Niemals direkt auf `main` pushen oder Force-Push verwenden — immer Feature-Branch + PR
- Niemals einen PR ohne menschliches Review mergen

## Team-Workflow (kurz, Details in CONTRIBUTING.md)

1. **Feature-Branches**: `feat/`, `fix/`, `refactor/`, `docs/`, `test/`, `chore/` + Kurzbeschreibung
2. **Commit-Messages**: Conventional Commits — `feat(stored-proc): sp_pay_vat_statement APPROVED→PAID`
3. **Pull Requests**: Template ausfüllen, mind. 1 Reviewer, Squash-Merge
4. **Issues**: offene Fragen, Bugs, Tasks und Schnittstellen-Klärungen werden als Issues geführt — siehe Templates unter `.github/ISSUE_TEMPLATE/`
5. **ADRs vor großen Architekturentscheidungen**: neue Datei in `docs/entscheidungen/`, dann Code

## Wenn du als Agent in diesem Repo arbeitest

- **Erst lesen**: diese Datei + `CONTRIBUTING.md` + relevante ADRs in `docs/entscheidungen/`
- **Branch anlegen** vor jeder inhaltlichen Änderung
- **Kleine commits**, logisch zusammengehörig
- **Bei Unklarheit zum Architektur-/Konventions-Punkt**: nicht raten — Frage notieren (in `docs/offene_fragen.md` und/oder als Issue) und User informieren
- **Sessions sind nicht selbstdokumentierend**: wichtige Erkenntnisse in ADR, Commit-Body oder `docs/offene_fragen.md` festhalten — der nächste Agent / das nächste Team-Mitglied findet sie sonst nicht
- **PR-Beschreibung ausführlich**: was, warum, wie getestet, Risiken — das Template fragt es ab

## Nützliche Referenzen

- Offizielle Konzepte: `docs/konzepte/MS1..MS4_G15.pdf`
- Namenskonventionen: `docs/namenskonventionen/` (nachreichen)
- Entscheidungen: `docs/entscheidungen/`
- Schnittstellen-Tabellen werden von Gruppen 4 (T_SUPPLIER_INVOICE), 7 (T_INVOICE), 8 (Zahlungen), 9/10 (Barrechnungen) befüllt
