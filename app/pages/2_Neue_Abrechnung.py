"""Neue Abrechnung anlegen oder DRAFT neu berechnen."""

from datetime import date
import sys
from pathlib import Path

import streamlit as st

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from app.services import vat

st.title("Neue Abrechnung")

today = date.today()
# Standardvorschlag: Vormonat
default_year = today.year if today.month > 1 else today.year - 1
default_month = today.month - 1 if today.month > 1 else 12

col1, col2 = st.columns(2)
with col1:
    year = st.number_input("Jahr", min_value=2020, max_value=2100, value=default_year, step=1)
with col2:
    month = st.number_input("Monat", min_value=1, max_value=12, value=default_month, step=1)

period = f"{int(year):04d}-{int(month):02d}"
st.write(f"Abrechnungsperiode: **{period}**")

# Vorläufiger User-Hack — später aus Auth/Session
created_by = st.text_input("Bearbeiter (User-Login)", value="s26s5xx")

if st.button("Abrechnung erstellen / neu berechnen", type="primary"):
    try:
        new_id = vat.create_statement(period, created_by)
        st.success(f"Abrechnung erstellt (ID {new_id}). Wechsle auf Detail-Seite zur Prüfung.")
    except Exception as exc:
        st.error(f"Fehlgeschlagen: {exc}")
