"""
Streamlit-Einstieg. Multi-Page-App: Streamlit findet automatisch die
Dateien unter pages/ und zeigt sie in der Sidebar.

Start:
    streamlit run app/main.py
"""

import streamlit as st

st.set_page_config(
    page_title="Umsatzsteuerabrechnung — SoPra G15",
    page_icon="📊",
    layout="wide",
)

st.title("Umsatzsteuerabrechnung")
st.caption("SoPra SoSe 2026 — Gruppe 15 — Adventure Bike ERP")

st.markdown(
    """
    Dieses Modul sammelt steuerrelevante Eingangs- und Ausgangsbelege je Monat,
    berechnet Zahllast oder Vorsteuerüberhang und friert die Belegbasis im
    Status-Workflow revisionsnah ein.

    Nutze die Navigation links:

    - **Übersicht** — alle bisherigen Abrechnungen
    - **Neue Abrechnung** — Periode anlegen / neu berechnen
    - **Detail** — Einzelne Abrechnung prüfen, freigeben, abschließen
    """
)

st.divider()
st.subheader("Hinweise")
st.info(
    "Für lokale Demo-Tests: `.env` auf `APP_DB_PROFILE=sandbox` setzen, Sandbox deployen "
    "und die Seed-Daten aus `sql/99_seed/` einspielen."
)
