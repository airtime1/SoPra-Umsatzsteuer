<!-- PR-Template — bitte ausfuellen, nicht loeschen.
     Konventionen siehe CONTRIBUTING.md -->

## Was ändert sich

<!-- 1-3 Saetze. Worum geht es konkret? -->

## Warum

<!-- Bezug zu ADR, Issue, offener Frage, Kundenanforderung.
     Beispiel: "Schliesst #12. Setzt ADR-002 um." -->

## Wie getestet

<!-- Konkrete Schritte / Befehle.
     Beispiel:
     - sql/03_stored_func/002_fn_g15_calculate_vat_balance.sql in Sandbox eingespielt
     - tests/sql/fn_g15_calculate_vat_balance_basic.sql ausgefuehrt -> alle Zeilen PASS
     - Streamlit-UI manuell durchgeklickt -->

## Risiken / Nebenwirkungen

<!-- Was koennte brechen?
     - Andere Stored Procs, die diese Funktion aufrufen?
     - Schnittstelle zu Gruppen 4/7/8/9/10?
     - Performance bei grossen Datenmengen?
     - "Nichts" ist auch eine valide Antwort. -->

## Checkliste

- [ ] Branch-Name folgt der Konvention (`feat/`, `fix/`, `docs/`, ...)
- [ ] Commit-Messages sind aussagekraeftig (Conventional Commits)
- [ ] Tests laufen lokal
- [ ] `CLAUDE.md` / `README.md` aktualisiert, falls relevant
- [ ] Neue Konventionen / Entscheidungen sind in `docs/entscheidungen/` festgehalten
- [ ] Keine Credentials, keine `.env`, keine Hochschul-DB-Dumps committed
- [ ] Mindestens ein Reviewer angepingt
