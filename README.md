# SoPra — Umsatzsteuerabrechnung (Gruppe 15)

Konzern-ERP-Modul für die monatliche Umsatzsteuerabrechnung. Liest Ein- und Ausgangsrechnungen aus vorgelagerten Modulen, aggregiert je Periode, berechnet Zahllast/Überhang, erzeugt einen revisionssicheren Abrechnungsbeleg.

Kontext, Architektur und Konventionen: siehe [`CLAUDE.md`](CLAUDE.md).

## Team

- Abel Adonai Mesfine
- Moritz Jahnke
- Nils Bachmann

## Tech-Stack

- **DB:** MS SQL Server (`ERPDEV26S` für Entwicklung, `s26s5xx_DATAMART` als Sandbox)
- **Frontend:** Python 3.11+ / Streamlit / pyodbc (Wechsel auf phpRunner bleibt offen)
- **Tests:** pytest + SQL-Skripte gegen Sandbox

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
```

### 3. Sandbox-DB vorbereiten

Skripte aus `sql/` der Reihe nach gegen die eigene Sandbox `s26s5xx_DATAMART` ausführen:

```powershell
python scripts\deploy_sandbox.py
```

### 4. Frontend starten

```powershell
streamlit run app\main.py
```

## Projektstruktur

| Ordner | Inhalt |
|---|---|
| `docs/konzepte/` | Offizielle Konzepte MS1–MS4 (Referenz, nicht editieren) |
| `docs/entscheidungen/` | Architekturentscheidungen (ADRs) |
| `docs/namenskonventionen/` | HdM-Namenskonvention (extern, in `docs/`) |
| `docs/inkonsistenzen.md` | Konflikte MS3/MS4 + Auflösung |
| `docs/offene_fragen.md` | Ans Team / Prof. / Architekt |
| `sql/00_setup` | T_CODE-Einträge — an Architekt liefern |
| `sql/01_tables` | CREATE TABLE — an Architekt liefern |
| `sql/02_views` | `list_views.*` Lese-Views |
| `sql/03_stored_func` | `stored_func.SF_*` |
| `sql/04_stored_proc` | `stored_proc.SP_*` |
| `sql/05_ins_upd_views` | `ins_views.*` / `upd_views.*` für Frontend-Schreibzugriff |
| `app/` | Streamlit-Frontend |
| `tests/` | Test- und Abnahmekonzept (MS5) |
| `scripts/` | Deploy-Helfer |

## Deadlines

- **MS5 Implementierung + Test-/Abnahmekonzept:** Mai 2026
- **Integrationstest:** Juni 2026
- **Golive:** Juli 2026
