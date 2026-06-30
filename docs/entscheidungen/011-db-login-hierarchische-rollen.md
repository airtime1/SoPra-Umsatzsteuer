# ADR-011: DB-Login und hierarchische Rollenlogik

- **Status:** akzeptiert
- **Datum:** 2026-06-29

## Kontext

Die Streamlit-App hatte bisher eine manuelle Rollensimulation ueber ein
Fachkraft-Dropdown (`FK1`/`FK2`/`FK3`). Das war fuer Demo-Zwecke brauchbar,
aber fachlich zu weit von der Datenbank entfernt: Buttons konnten mit einer
ausgewaehlten Demo-Rolle angezeigt werden, waehrend der tatsaechliche
DB-Aufrufer weiterhin der APP-User war.

Die Live-Pruefung gegen `ERPDEV26S` am 2026-06-29 ergab:

- `list_views.V_LIST_G15_VAT_USER` ist dort nicht deployed.
- Die zentrale Funktion `dbo.fn_get_user_securitylevel` ist erreichbar und
  bleibt die massgebliche Quelle fuer `T_USER.SECURITYLEVEL`.

## Entscheidung

Die App nutzt beim Start einen Login mit echten DB-Credentials. Nach
erfolgreicher Verbindung ermittelt sie den Benutzer ueber `SUSER_SNAME()` und
den Security-Level ueber `dbo.fn_get_user_securitylevel(SUSER_SNAME())`.

Die Rollenlogik ist hierarchisch:

- Level 1 darf Level-1-Aktionen.
- Level 2 darf Level-1- und Level-2-Aktionen.
- Level 3 darf Level-1-, Level-2- und Level-3-Aktionen.

Die UI blendet Aktionen nach derselben `actual_level >= required_level`-Regel
ein, die auch die Stored Procedures erzwingen. `T_CODE_NEXT.SECURITY_LEVEL`
bleibt die DB-Konfiguration fuer Statusuebergaenge und beschreibt nun den
Mindest-Level.

Die Stored Procedures vertrauen dem uebergebenen Audit-Parameter nicht blind:
`@created_by`, `@approved_by`, `@paid_by` bzw. `@rejected_by` muessen dem
aktuellen `SUSER_SNAME()` entsprechen; andernfalls wird der Aufruf abgelehnt.

## Konsequenzen

- Das Fachkraft-Dropdown entfaellt vollstaendig.
- Audit-Felder (`CREATED_BY`, `APPROVED_BY`, `CLOSED_BY`) erhalten den echten
  DB-Login aus `SUSER_SNAME()`.
- Der alte gemeinsame APP-Laufzeituser wird nicht mehr fuer die UI verwendet.
- Echte DB-User brauchen die noetigen Rechte auf G15-Views, Functions und
  Procedures.
- `list_views.V_LIST_G15_VAT_USER` kann fuer Sandbox/Diagnose bestehen bleiben,
  ist aber keine Laufzeitvoraussetzung der UI.
