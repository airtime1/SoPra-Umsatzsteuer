# Deployment auf Streamlit Community Cloud

Die finale UI laeuft als oeffentliche Streamlit-App. Hosting-Plattform ist
**Streamlit Community Cloud** (kostenlos, GitHub-gekoppelt). Cloudflare o. ae.
kommt nicht in Frage: Streamlit braucht einen dauerlaufenden Python-Server +
ODBC-Treiber, kein statisches/Worker-Hosting.

## Voraussetzungen im Repo

- `requirements.txt` — Python-Pakete (inkl. `pyodbc`).
- `packages.txt` — System-Pakete (apt) fuer den SQL-Server-Treiber in der Cloud:
  `unixodbc`, `freetds-bin`, `freetds-dev`, `tdsodbc`. Damit steht der
  **FreeTDS**-ODBC-Treiber bereit (Microsofts `msodbcsql` laesst sich auf
  Streamlit Cloud nicht installieren).

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
   APP_USER       = "<app-user>"
   APP_PASSWORD   = "<app-pass>"
   ODBC_DRIVER    = "/usr/lib/x86_64-linux-gnu/odbc/libtdsodbc.so"
   ```

   Der absolute Pfad zur FreeTDS-Lib ist robuster als der Treibername
   `FreeTDS` (keine Abhaengigkeit von der odbcinst-Registrierung).

## FreeTDS-Besonderheit

`app/db.py` ergaenzt den Connection-String nur bei FreeTDS automatisch um
`PORT` (Default 1433, ueberschreibbar via Secret `DB_PORT`) und
`TDS_Version=7.4`. Lokal mit dem Microsoft-ODBC-Treiber bleibt alles wie bisher.

## Hinweise

- Secrets niemals committen — nur in der Streamlit-Cloud-UI.
- Der `APP_USER` braucht `SELECT` auf `list_views.*` und `EXECUTE` auf
  `stored_proc.sp_G15_*`.
- Free-Tier: Die App schlaeft bei Inaktivitaet ein (~30 s Aufwachzeit) — vor
  einer Vorstellung einmal aufwecken.
- Die HdM-DB muss oeffentlich erreichbar sein (ist sie); kein VPN noetig.
