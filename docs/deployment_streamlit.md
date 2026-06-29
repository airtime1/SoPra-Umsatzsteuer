# Deployment auf Streamlit Community Cloud

Die finale UI laeuft als oeffentliche Streamlit-App. Hosting-Plattform ist
**Streamlit Community Cloud** (kostenlos, GitHub-gekoppelt). Cloudflare o. ae.
kommt nicht in Frage: Streamlit braucht einen dauerlaufenden Python-Server.

## DB-Treiber: pymssql (kein System-ODBC-Treiber)

Die App-Connection (`app/db.py` -> `get_app_conn`) nutzt **pymssql**. pymssql
bringt FreeTDS im Python-Wheel mit und braucht **keine System-Pakete**.

- **Kein `packages.txt`** noetig (und es darf keins geben): Der ODBC-Weg
  (`pyodbc` + `tdsodbc`/`msodbcsql`) ist auf dem Streamlit-Image (Debian trixie)
  nicht installierbar — `tdsodbc` zieht `libodbc1` aus dem MS-apt-Repo nach, das
  mit dem vorinstallierten `libodbc2` kollidiert
  (`trying to overwrite '/usr/lib/.../libodbc.so.2.0.0'`) -> Build-Abbruch.
- `requirements.txt` enthaelt `pymssql` (App) und weiterhin `pyodbc`
  (nur fuer lokale Deploy-/Analyse-Skripte via `get_dev_conn`/`get_sandbox_conn`).

## App anlegen (share.streamlit.io)

1. **Create app -> Deploy a public app from GitHub.**
2. Repository `airtime1/SoPra-Umsatzsteuer`, Branch `main`,
   Main file path `app/main.py`.
3. **Advanced settings -> Secrets** (TOML, flach; Streamlit stellt Top-Level-Keys
   als Environment-Variablen bereit, die `app/db.py` ueber `os.environ` liest):

   ```toml
   APP_DB_PROFILE = "app"
   APP_SERVER     = "edu.hdm-server.eu"
   APP_DATABASE   = "ERPDEV26S"
   APP_USER       = "ERP_REMOTE_USER"
   APP_PASSWORD   = "<app-pass>"
   ```

   - **`ODBC_DRIVER` wird NICHT mehr gebraucht** (war nur fuer den pyodbc-Weg).
   - Optional `DB_PORT` (Default `1433`).

## Hinweise

- Secrets niemals committen — nur in der Streamlit-Cloud-UI.
- Der `APP_USER` (`ERP_REMOTE_USER`) braucht `SELECT` auf `list_views.*`,
  `dbo.T_USER`, `dbo.T_CODE`/`T_CODE_NEXT` und `EXECUTE` auf
  `stored_proc.sp_G15_*`. (Lokal verifiziert: Lese-Pfade + 108 User aus
  `dbo.T_USER` funktionieren.)
- Free-Tier: Die App schlaeft bei Inaktivitaet ein (~30 s Aufwachzeit) — vor
  einer Vorstellung einmal aufwecken.
- Die HdM-DB ist oeffentlich erreichbar (kein VPN noetig).
