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

try:
    users = vat.list_users()
except Exception as exc:
    st.error(f"Benutzer-/Rollenliste konnte nicht geladen werden: {exc}")
    st.stop()

today = date.today()
# Standardvorschlag: letzte Periode, die nach der 10.-des-Folgemonats-Regel
# bereits abgerechnet werden darf.
month_offset = 1 if today.day >= 10 else 2
default_year = today.year
default_month = today.month - month_offset
while default_month <= 0:
    default_month += 12
    default_year -= 1

col1, col2 = st.columns(2)
with col1:
    year = st.number_input("Jahr", min_value=2020, max_value=2100, value=default_year, step=1)
with col2:
    month = st.number_input("Monat", min_value=1, max_value=12, value=default_month, step=1)

period = f"{int(year):04d}-{int(month):02d}"
st.write(f"Abrechnungsperiode: **{period}**")

clerks = users[users["SECURITYLEVEL"] == 1]
if clerks.empty:
    created_by = st.text_input("Bearbeiter (User-Login)", value="")
else:
    created_by = st.selectbox(
        "Bearbeiter",
        options=clerks["USERNAME"].tolist(),
        format_func=lambda user: f"{user} — Sachbearbeiter",
    )

if st.button("Abrechnung erstellen / neu berechnen", type="primary"):
    try:
        new_id = vat.create_statement(period, created_by)
        st.success(f"Abrechnung erstellt (ID {new_id}). Wechsle auf Detail-Seite zur Prüfung.")
    except Exception as exc:
        st.error(f"Fehlgeschlagen: {exc}")
