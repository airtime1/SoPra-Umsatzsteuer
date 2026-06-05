# Onboarding — neues Team-Mitglied

Diese Anleitung bringt dich in **≈ 20 Minuten** vom Nullzustand zu „kann lokal entwickeln und PRs machen". Geh sie der Reihe nach durch, hak alles ab.

> **Wenn etwas klemmt:** WhatsApp-Gruppe „Fiskal aut morere" oder beim nächsten Montagstreffen ansprechen. Lieber früh fragen als später debuggen.

## 0. Voraussetzung: Einladung annehmen

Du solltest eine Mail von GitHub bekommen haben mit dem Betreff *„airtime1 invited you to airtime1/SoPra-Umsatzsteuer"*. Auf den Link klicken → **Accept invitation**. Wenn die Mail nicht da ist: bei Nils melden, er lädt nochmal ein.

## 1. Tools installieren (einmalig)

| Tool | Wofür | Download |
|---|---|---|
| **Git** | Versionierung | https://git-scm.com/ |
| **Python 3.11+** | Frontend + Tests | https://www.python.org/downloads/ |
| **ODBC Driver 17 oder 18 für SQL Server** | DB-Verbindung | [Microsoft Download](https://learn.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server) |
| **GitHub CLI `gh`** *(optional, sehr praktisch)* | Issues/PRs ohne Browser | https://cli.github.com/ |
| **VS Code** *(Empfehlung)* | Editor mit SQL- und Python-Support | https://code.visualstudio.com/ |

Bei Python: **„Add Python to PATH"** im Installer ankreuzen, sonst gibt's PowerShell-Stress.

## 2. Git-Identität setzen (einmalig)

PowerShell öffnen und ausführen — **Platzhalter ersetzen**:

```powershell
git config --global user.name "<Vorname Nachname>"
git config --global user.email "<deine-github-mail>"
```

`<deine-github-mail>` ist die Mail-Adresse, die in deinem GitHub-Account hinterlegt ist (siehe https://github.com/settings/emails). Wenn die nicht passt, werden deine Commits nicht zu deinem Profil zugeordnet.

Check:
```powershell
git config --global --get user.name
git config --global --get user.email
```

## 3. GitHub-Auth einrichten

**Variante A — bequem mit `gh`:**
```powershell
gh auth login
```
Prompt-Antworten: `GitHub.com` → `HTTPS` → `Yes` → `Login with a web browser`. Browser öffnet sich, einmal bestätigen, fertig.

**Variante B — falls `gh` nicht installiert:** Beim ersten `git push` fragt Git nach Login. Windows Credential Manager merkt es sich ab dann. Statt Passwort musst du ein **Personal Access Token** (PAT) verwenden — generieren unter https://github.com/settings/tokens → „Generate new token (classic)" → Scope `repo` reicht.

## 4. Repo klonen

PowerShell, in dem Ordner, in dem ihr eure Projekte habt:

```powershell
cd <dein-projekt-ordner>      # z.B. cd C:\Users\<du>\Documents\Projekte
git clone https://github.com/airtime1/SoPra-Umsatzsteuer.git
cd SoPra-Umsatzsteuer
```

## 5. Python-Umgebung aufsetzen

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

Falls PowerShell beim Aktivieren meckert (`cannot be loaded because running scripts is disabled`), einmalig:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```
und dann die Aktivierung nochmal.

## 6. DB-Credentials eintragen

```powershell
Copy-Item .env.example .env
```

Dann `.env` öffnen (VS Code: `code .env`) und ausfüllen:

```ini
# Deine persönliche HdM-Kennung — überall ersetzen wo "s26s5xx" steht
DEV_USER=<dein-s26-user>
DEV_PASSWORD=<dein-hdm-db-passwort>
SANDBOX_DATABASE=<dein-s26-user>_DATAMART
SANDBOX_USER=<dein-s26-user>
SANDBOX_PASSWORD=<dein-hdm-db-passwort>

# Frontend-User ist für alle gleich (steht schon im .env.example)
APP_USER=ERP_REMOTE_USER
APP_PASSWORD=Password123
```

> ⚠️ **`.env` ist via `.gitignore` vom Commit ausgeschlossen — das ist Absicht.** Niemals versuchen, das zu umgehen. Wenn `git status` deine `.env` zeigt, **STOP** und im Team melden.

## 7. Verbindung testen

```powershell
streamlit run app\main.py
```

Browser sollte sich auf http://localhost:8501 öffnen. Auf „Übersicht" klicken — wenn keine Fehlermeldung kommt, ist die DB-Verbindung sauber. Tabelle wird leer sein, solange noch keine Abrechnungen angelegt wurden — das ist erwartet.

Wenn ein **ODBC-Fehler** kommt: Driver-Name in `.env` prüfen. Bei ODBC 18 muss es heißen:
```ini
ODBC_DRIVER=ODBC Driver 18 for SQL Server
```

Wenn ein **Login-Fehler** kommt: HdM-VPN starten (falls von zu Hause aus), Passwort doppelt prüfen.

## 8. Orientierung im Repo (10 Minuten Lesen)

Bevor du loslegst, einmal kurz reinschauen:

| Datei | Was steht drin |
|---|---|
| [`CLAUDE.md`](CLAUDE.md) | **Zentrales Briefing** — Tech-Stack, Team, Konventionen, alle Architekturentscheidungen verlinkt. Auch der KI-Agent (Claude/Codex) liest die automatisch. |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | **Workflow-Regeln** — wie wir Branches benennen, Commits schreiben, PRs machen. Bitte ganz lesen. |
| [`docs/entscheidungen/`](docs/entscheidungen/) | **ADRs 001–007** — warum wir Status englisch nennen, warum Saldo immer positiv ist, etc. |
| [`docs/inkonsistenzen.md`](docs/inkonsistenzen.md) | MS3 ↔ MS4 Konflikte und wie wir sie aufgelöst haben |
| [GitHub Issues](https://github.com/airtime1/SoPra-Umsatzsteuer/issues) | **Offene Punkte mit Status & Adressat** — das ist die Source of Truth für „was ist noch zu tun" |

## 9. Erstes Mal mitarbeiten

Niemals direkt auf `main` — branchen und PR.

```powershell
git checkout main && git pull
git checkout -b feat/<kurze-beschreibung>     # z.B. feat/seed-daten-januar
# arbeiten ...
git add <files>
git commit -m "feat(sql): Seed-Daten fuer Standardperiode"
git push -u origin feat/<kurze-beschreibung>
gh pr create                                  # oder via GitHub-Web: "Compare & pull request"
```

Im PR: Template ausfüllen (kommt automatisch), mindestens 1 Reviewer anpingen, warten auf Approval, dann **„Squash and merge"**.

## 10. Sich ein Issue schnappen

```powershell
gh issue list                                 # Übersicht
gh issue view 14                              # Detail
gh issue edit 14 --add-assignee @me           # mir zuteilen
```

Oder über die Web-UI: https://github.com/airtime1/SoPra-Umsatzsteuer/issues

**Empfohlene Reihenfolge für den Einstieg:**
- Issue #13 (Aufgabenteilung MS5) — beim nächsten Treffen klären
- Issues mit `prio: hoch` und `phase: ms5` — was wir kurzfristig brauchen
- Schnittstellen-Issues (#4, #5, #6, #7) — wer hat einen Draht zu Gruppe 4/7?

---

## Häufige Stolpersteine

| Problem | Lösung |
|---|---|
| `ODBC Driver not found` | Driver installieren (Schritt 1) und `.env` → `ODBC_DRIVER` anpassen |
| `Login failed for user s26sXXXX` | HdM-VPN aktivieren, Passwort prüfen |
| `git push` blockiert mit „Branch protection violation" | Du pushst direkt auf `main` — Feature-Branch + PR machen (siehe Schritt 9) |
| `.env` taucht in `git status` auf | `git rm --cached .env` und committen; `.gitignore` enthält `.env` bereits, also: nicht erzwingen, sondern fragen |
| Streamlit-Fehler „No module named 'app'" | Aus dem Projekt-Root starten: `streamlit run app\main.py` (nicht aus `app/` heraus) |
| PowerShell aktiviert venv nicht | `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser` |

## Fertig?

Hak ab, wenn erledigt:

- [ ] Einladung angenommen
- [ ] Tools installiert
- [ ] Git-Identität gesetzt und gecheckt
- [ ] Repo geklont
- [ ] `pip install -r requirements.txt` ohne Fehler
- [ ] `.env` mit eigenen Credentials erstellt
- [ ] `streamlit run app\main.py` läuft, Übersicht ohne Fehler
- [ ] `CLAUDE.md` und `CONTRIBUTING.md` einmal überflogen

Wenn alle 8 Häkchen stehen, bist du startklar. Im Team kurz Bescheid geben — dann kann dir jemand dein erstes Issue zuweisen oder mit dir ein PaarProgramming-Setup für den ersten PR machen.

Willkommen 👋
