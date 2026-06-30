# Deployment auf Streamlit Community Cloud

Die finale UI laeuft als oeffentliche Streamlit-App. Hosting-Plattform ist
**Streamlit Community Cloud** (kostenlos, GitHub-gekoppelt). Cloudflare o. ae.
kommt nicht in Frage: Streamlit braucht einen dauerlaufenden Python-Server.

## DB-Treiber und Login

Die App nutzt **pymssql** fuer Verbindungen mit dem im UI eingegebenen
DB-User (`app/db.py` -> `get_user_conn`). pymssql bringt FreeTDS im
Python-Wheel mit und braucht **keine System-Pakete**.

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
   APP_SERVER     = "edu.hdm-server.eu"
   APP_DATABASE   = "ERPDEV26S"
   ```

   - **`ODBC_DRIVER` wird NICHT mehr gebraucht** (war nur fuer den pyodbc-Weg).
   - Optional `DB_PORT` (Default `1433`).
   - Keine DB-Passwoerter in Streamlit-Secrets hinterlegen; Benutzer geben ihre
     eigenen DB-Credentials beim Start im Loginformular ein.

## Hinweise

- Secrets niemals committen — nur in der Streamlit-Cloud-UI.
- Echte DB-User brauchen `SELECT` auf den G15-Views und `dbo.T_CODE`/
  `T_CODE_NEXT`, `EXECUTE` auf `stored_func.fn_G15_check_vat_period` und
  `stored_proc.sp_G15_*` sowie `SELECT` auf
  `stored_func.fn_G15_calculate_vat_balance`. Die Rollenlogik liest den Level
  ueber `dbo.fn_get_user_securitylevel(SUSER_SNAME())`.
- Free-Tier: Die App schlaeft bei Inaktivitaet ein (~30 s Aufwachzeit) — vor
  einer Vorstellung einmal aufwecken.
- Die HdM-DB ist oeffentlich erreichbar (kein VPN noetig).
