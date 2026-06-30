# ADR-006: Frontend-Stack Python + Streamlit (mit Wechsel-Option phpRunner)

- **Status:** vorgeschlagen (Team-Bestätigung steht aus)
- **Datum:** 2026-06-03

## Kontext

HdM erlaubt für das Frontend Python, C# oder phpRunner. MS4 hatte `php-Runner` festgelegt. Aktuell überlegt das Team, doch auf Python zu wechseln. Wechsel-Option zurück zu phpRunner soll möglichst lange offenbleiben.

## Optionen

1. **phpRunner** — laut MS4. Standard im SoPra-Kontext, gut dokumentiert in Kurs-Materialien.
2. **Python + Streamlit** — schnelle UI-Entwicklung, sauberes Testing, Wechsel auf phpRunner möglich, weil dünne UI-Schicht.
3. **Python + Flask + Jinja2** — flexibler als Streamlit, aber mehr UI-Code.
4. **C#** — kein Vorteil für das Team erkennbar.

## Entscheidung

**Option 2 (Python + Streamlit; UI-Verbindung mit pymssql, Deploy-/Analyse-Skripte weiter mit pyodbc).**

Begründung:
- Geschwindigkeit: Streamlit baut formular- und listenorientierte UIs ohne HTML/CSS-Aufwand.
- Wechsel-Sicherheit: Alle Logik liegt in der DB (Stored Procs/Functions), das Frontend ist nur Aufruf-Schicht. Ein Wechsel zu phpRunner ersetzt nur den `app/`-Ordner, alles in `sql/` bleibt.
- Testing: pytest direkt gegen die Sandbox-DB ist Standard.
- Risiko: Niedrig, wenn mindestens ein Teammitglied Python-Erfahrung hat. Die UI nutzt inzwischen `pymssql`, weil das ohne System-ODBC-Treiber auf Streamlit Community Cloud laeuft.

## Konsequenzen

- `requirements.txt` mit `streamlit`, `pymssql`, `pyodbc`, `python-dotenv`, `pandas`, `pytest`.
- ODBC-Driver muss lokal installiert sein (Setup-Hinweis in README).
- Stichtag für Wechsel zurück zu phpRunner: **muss noch festgelegt werden** — siehe `docs/offene_fragen.md`. Empfehlung: spätestens nach erfolgreicher Stored-Procs-/-Functions-Phase, weil danach ein Wechsel günstig ist.
- Falls Wechsel: Streamlit-Pages 1:1 als phpRunner-Templates nachbauen, DB-Aufrufe sind identisch (Stored Procs).
