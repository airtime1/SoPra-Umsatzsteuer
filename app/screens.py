"""Wiederverwendbare Streamlit-Screens."""

from __future__ import annotations

from datetime import date

import streamlit as st

from app import ui
from app.services import vat


def render_overview() -> None:
    ui.apply_theme()
    ui.render_sidebar("overview")

    try:
        profiles = vat.list_fachkraefte()
        statements = vat.list_statements()
        transitions = vat.list_status_transitions()
    except Exception as exc:
        ui.show_error_dialog("DB-Zugriff fehlgeschlagen", exc)
        st.stop()

    profile = ui.render_header("Umsatzsteuerabrechnung", profiles)

    current_period = vat.latest_billable_period()
    current_statement = None
    if not statements.empty:
        matches = statements[statements["VAT_PERIOD"].astype(str) == current_period]
        if not matches.empty:
            current_statement = matches.iloc[0]

    current_row = current_statement if current_statement is not None else ui.empty_statement_row()

    drafts = ui.sortable_statements(statements[statements["VAT_STATUS"] == "DRAFT"]) if not statements.empty else statements
    year = date.today().year
    year_rows = statements[statements["VAT_PERIOD"].astype(str).str.startswith(str(year))] if not statements.empty else statements
    year_summary = ui.yearly_summary(year_rows)

    with st.container(border=True):
        title_cols = st.columns([1, 0.16], vertical_alignment="center")
        with title_cols[0]:
            st.markdown(
                f"""
                <div class="card-title">
                    <span class="icon-badge">{ui.icon_svg("calendar")}</span>
                    <h2>{current_period}</h2>
                    <span class="period-tag">Letzte abrechenbare Periode</span>
                </div>
                """,
                unsafe_allow_html=True,
            )
        with title_cols[1]:
            if ui.can_edit_statement(current_statement, profile, transitions):
                if st.button("Bearbeiten", type="primary", use_container_width=True):
                    st.session_state["selected_statement_id"] = int(current_row["VAT_STATEMENT_ID"])
                    st.switch_page("pages/3_Abrechnung_auswählen.py")

        ui.render_statement_header_table(current_row, action=True)

    spacer_a, spacer_b = st.columns([0.42, 0.58])

    with spacer_a:
        with st.container(border=True):
            ui.card_title("Offene Drafts", "document", badge=len(drafts), orange=True)
            ui.render_draft_rows(drafts, key_prefix="overview-draft", limit=2)
            if not drafts.empty and st.button(
                "Alle Drafts anzeigen",
                key="all-drafts",
                type="primary",
                use_container_width=False,
            ):
                ui.drafts_dialog(drafts)

    with spacer_b:
        with st.container(border=True):
            ui.card_title(str(year), "bar-chart")
            st.markdown(
                f"""
                <div class="mock-table">
                    <div class="table-head year-grid">
                        <span>Umsatzsteuer</span><span>Vorsteuer</span><span>Saldo</span><span>Type</span>
                    </div>
                    <div class="table-row year-grid">
                        <span>{ui.format_currency(year_summary["output"])}</span>
                        <span>{ui.format_currency(year_summary["input"])}</span>
                        <span class="{ui.value_class(year_summary["type"])}">{ui.format_currency(year_summary["balance"])}</span>
                        <span class="{ui.value_class(year_summary["type"])}">{ui.type_label(year_summary["type"])}</span>
                    </div>
                </div>
                """,
                unsafe_allow_html=True,
            )

    with st.container(border=True):
        header_cols = st.columns([1, 0.16], vertical_alignment="center")
        with header_cols[0]:
            ui.card_title("Alle Umsatzsteuerabrechnungen", "document")
        with header_cols[1]:
            if profile.level == 1:
                if st.button("Hinzufügen", type="primary", use_container_width=True):
                    st.switch_page("pages/2_Neue_Abrechnung.py")
        ui.render_all_statement_rows(ui.sortable_statements(statements), key_prefix="overview-all")
