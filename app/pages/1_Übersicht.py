"""Übersichts-Seite — alle Abrechnungen tabellarisch."""

import sys
from pathlib import Path

import streamlit as st

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from app.services import vat

st.title("Abrechnungs-Übersicht")

try:
    df = vat.list_statements()
except Exception as exc:
    st.error(f"DB-Zugriff fehlgeschlagen: {exc}")
    st.stop()

if df.empty:
    st.info("Noch keine Abrechnungen vorhanden.")
else:
    st.dataframe(df, use_container_width=True, hide_index=True)
