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
    Willkommen im Modul **Umsatzsteuerabrechnung**.

    Nutze die Navigation links:

    - **Übersicht** — alle bisherigen Abrechnungen
    - **Neue Abrechnung** — Periode anlegen / neu berechnen
    - **Detail** — Einzelne Abrechnung prüfen, freigeben, abschließen
    """
)

st.divider()
st.subheader("Hinweise")
st.info(
    "Diese App ist in der Entwicklung. Implementierte Funktionen: Anlage einer Abrechnung "
    "(über SP_CREATE_VAT_STATEMENT). Status-Workflow (DRAFT → APPROVED → PAID) wird gerade gebaut."
)
