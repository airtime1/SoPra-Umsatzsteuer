# SoPra — Umsatzsteuerabrechnung (Gruppe 15)

Konzern-ERP-Modul für die monatliche Umsatzsteuerabrechnung. Liest Ein- und Ausgangsrechnungen aus vorgelagerten Modulen, aggregiert je Periode, berechnet Zahllast/Überhang, erzeugt einen revisionssicheren Abrechnungsbeleg.

**Neu im Projekt?** Folge der [`ONBOARDING.md`](ONBOARDING.md) — komplettes Setup in ≈ 20 Minuten.

**Agenten-Briefing:** [`AGENTS.md`](AGENTS.md) · **Claude-Einstieg:** [`CLAUDE.md`](CLAUDE.md) · **Mitarbeiten:** [`CONTRIBUTING.md`](CONTRIBUTING.md) · **Entscheidungen:** [`docs/entscheidungen/`](docs/entscheidungen/) · **Offene Fragen:** [GitHub Issues](../../issues)

## Team

- Abel Adonai Mesfine
- Moritz Jahnke
- Nils Bachmann

## Tech-Stack

- **DB:** MS SQL Server (`ERPDEV26S` für Entwicklung, `s26s5xx_DATAMART` als Sandbox)
- **Frontend:** Python 3.11+ / Streamlit / pyodbc (Wechsel auf phpRunner bleibt offen)
- **Tests:** SQL-Skripte gegen Sandbox inkl. Demo-Workflow; pytest-Wrapper geplant

## Quickstart

### 1. Voraussetzungen

- Python 3.11+
- ODBC Driver 17 oder 18 für SQL Server ([Microsoft Download](https://learn.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server))
- Zugang zu `edu.hdm-server.eu` (HdM-VPN ggf. nötig)

### 2. Setup

```powershell
git clone <repo-url>
cd SoPra-Umsatzsteuer

python -m venv .venv
.\.venv\Scripts\Activate.ps1

pip install -r requirements.txt

Copy-Item .env.example .env
# .env öffnen, Credentials eintragen
# Die finale Streamlit-App nutzt den APP-Zugang; APP_* Credentials eintragen
```

### 3. Sandbox-DB vorbereiten

Skripte aus `sql/` der Reihe nach gegen die eigene Sandbox `s26s5xx_DATAMART` ausführen. Dabei werden auch die Demo-Seed-Daten aus `sql/99_seed/` eingespielt:

```powershell
python scripts\deploy_sandbox.py
```

### 4. Frontend starten

```powershell
streamlit run app\main.py
```

Die finale App nutzt den vorgesehenen APP-Zugang auf `ERPDEV26S` direkt. Sandbox- und Dev-Connection-Helfer bleiben für Deploy-/Analyse-Skripte vorhanden, sind aber nicht die Laufzeitbasis der UI.

### 5. Demo-Workflow prüfen

- In der App: Übersicht öffnen, neue abrechenbare Periode erstellen, `Abrechnung auswählen` prüfen, freigeben, abschließen.
- Per SQL: Tests aus `tests/sql/` gegen die Sandbox ausführen; die Demo-Tests erwarten in allen Ergebniszeilen `PASS`.

## Projektstruktur

| Pfad | Inhalt |
|---|---|
| `AGENTS.md` | Gemeinsames Briefing fuer Claude, Codex und andere KI-Agents |
| `CLAUDE.md` | Schlanker Claude-Einstieg mit Verweis auf `AGENTS.md` |
| `docs/konzepte/` | Offizielle Konzepte MS1–MS5 (Referenz, nicht editieren) |
| `docs/zielbild.md` | Aktuelles fachliches Zielbild nach Konzept- und DEV-DB-Prüfung |
| `docs/schnittstellen_annahmen.md` | Geprüfte Fremdtabellen/-Views, Annahmen und offene Schnittstellenfragen |
| `docs/entscheidungen/` | Architekturentscheidungen (ADRs) |
| `docs/namenskonventionen/` | HdM-Namenskonvention (extern, in `docs/`) |
| `docs/inkonsistenzen.md` | Konflikte MS3/MS4 + Auflösung |
| `docs/offene_fragen.md` | Ans Team / Prof. / Architekt |
| `sql/00_setup` | T_CODE-Einträge — an Architekt liefern |
| `sql/01_tables` | CREATE TABLE — an Architekt liefern |
| `sql/02_views` | `list_views.*` Lese-Views |
| `sql/03_stored_func` | `stored_func.fn_*` |
| `sql/04_stored_proc` | `stored_proc.sp_*` |
| `sql/05_ins_upd_views` | `ins_views.*` / `upd_views.*` für Frontend-Schreibzugriff |
| `sql/99_seed` | Realistische Demo-Daten für die Sandbox |
| `app/` | Streamlit-Frontend |
| `tests/` | Test- und Abnahmekonzept (MS5) |
| `scripts/` | Deploy-Helfer |

## Workflow (kurz)

Komplette Konventionen in [`CONTRIBUTING.md`](CONTRIBUTING.md).

```bash
# Feature angehen
git status --short --branch
git fetch origin
git checkout main
git pull --ff-only
git checkout -b feat/<kurz-beschreibung>

# arbeiten, oft committen mit Conventional Commits
git commit -m "feat(stored-proc): sp_pay_vat_statement"

# pushen, PR auf GitHub aufmachen
git push -u origin feat/<kurz-beschreibung>
gh pr create   # oder: GitHub-UI
```

Niemals direkt auf `main` pushen. Mindestens 1 Review, dann Squash-Merge.

## Deadlines

- **MS5 Implementierung + Test-/Abnahmekonzept:** Mai 2026
- **Integrationstest:** Juni 2026
- **Golive:** Juli 2026
