"""Gemeinsame UI-Bausteine fuer das Streamlit-Finanzcockpit."""

from __future__ import annotations

import html
from datetime import date
from decimal import Decimal, InvalidOperation
from textwrap import dedent
from typing import Any, Iterable

import pandas as pd
import streamlit as st

from app.services import vat


STATUS_ORDER = {"DRAFT": 0, "APPROVED": 1, "PAID": 2}
STATUS_LABELS = {
    "DRAFT": "Draft",
    "APPROVED": "Freigegeben",
    "PAID": "Übermittelt",
}
STATUS_TONES = {
    "DRAFT": "draft",
    "APPROVED": "approved",
    "PAID": "paid",
}
VAT_TYPE_LABELS = {
    "ZAHLLAST": "Zahllast",
    "UEBERHANG": "Überhang",
    "NEUTRAL": "Neutral",
}

ICONS = {
    "arrow-down": '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 5v14"/><path d="m19 12-7 7-7-7"/></svg>',
    "arrow-up": '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 19V5"/><path d="m5 12 7-7 7 7"/></svg>',
    "bar-chart": '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 20V10"/><path d="M10 20V4"/><path d="M16 20v-7"/><path d="M22 20H2"/></svg>',
    "calendar": '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M8 2v4"/><path d="M16 2v4"/><rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 10h18"/></svg>',
    "clock": '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>',
    "document": '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8Z"/><path d="M14 2v6h6"/><path d="M8 13h8"/><path d="M8 17h6"/></svg>',
    "edit": '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4Z"/></svg>',
    "file-plus": '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8Z"/><path d="M14 2v6h6"/><path d="M12 18v-6"/><path d="M9 15h6"/></svg>',
    "folder": '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 7a2 2 0 0 1 2-2h5l2 2h7a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2Z"/></svg>',
    "home": '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m3 11 9-8 9 8"/><path d="M5 10v10h14V10"/><path d="M9 20v-6h6v6"/></svg>',
    "log-out": '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><path d="M16 17l5-5-5-5"/><path d="M21 12H9"/></svg>',
    "plus-circle": '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M12 8v8"/><path d="M8 12h8"/></svg>',
    "refresh": '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M21 12a9 9 0 0 1-15.5 6.3L3 16"/><path d="M3 16v5h5"/><path d="M3 12A9 9 0 0 1 18.5 5.7L21 8"/><path d="M21 8V3h-5"/></svg>',
    "upload": '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><path d="m17 8-5-5-5 5"/><path d="M12 3v12"/></svg>',
    "user": '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="8" r="4"/><path d="M20 21a8 8 0 0 0-16 0"/></svg>',
}


def apply_theme() -> None:
    st.markdown(
        """
        <style>
        :root {
            --app-blue: #0f62ff;
            --app-blue-2: #155be7;
            --app-ink: #07122d;
            --app-muted: #62708c;
            --app-border: #dbe7fb;
            --app-soft: #f6f9ff;
            --app-card: #ffffff;
            --app-red: #ff2525;
            --app-green: #0a8f42;
            --app-orange: #ff6b00;
        }

        .stApp {
            background:
                radial-gradient(circle at 78% 18%, rgba(15, 98, 255, 0.045), transparent 34rem),
                linear-gradient(180deg, #ffffff 0%, #f8fbff 100%);
            color: var(--app-ink);
        }

        .block-container {
            max-width: 1320px;
            padding: 2.15rem 2.3rem 3rem 170px;
        }

        [data-testid="stSidebar"],
        [data-testid="stSidebarCollapsedControl"] {
            display: none !important;
        }

        .app-sidebar {
            background: #fbfdff;
            border-right: 1px solid #dfe8f7;
            bottom: 0;
            left: 0;
            padding: 1.95rem 0.7rem;
            position: fixed;
            top: 0;
            width: 132px;
            z-index: 999999;
        }

        .logo-tile {
            align-items: center;
            background: linear-gradient(135deg, #1e6bff, #0a4be8);
            border-radius: 14px;
            box-shadow: 0 10px 24px rgba(15, 98, 255, 0.22);
            color: white;
            display: flex;
            font-size: 1.8rem;
            font-weight: 800;
            height: 46px;
            justify-content: center;
            margin: 0.2rem auto 2rem;
            width: 46px;
        }

        .sidebar-meta {
            bottom: 1.4rem;
            color: #5b6880;
            font-size: 0.76rem;
            left: 1.05rem;
            position: absolute;
        }

        .sidebar-meta div {
            margin-top: 1rem;
        }

        .nav-link {
            align-items: center;
            border-radius: 10px;
            color: #52617a;
            display: flex;
            flex-direction: column;
            font-size: 0.82rem;
            font-weight: 650;
            gap: 0.45rem;
            justify-content: center;
            margin: 0.55rem 0;
            min-height: 78px;
            text-align: center;
            text-decoration: none !important;
            transition: background 150ms ease, color 150ms ease, box-shadow 150ms ease;
        }

        .nav-link:hover,
        .nav-link.active {
            background: #edf4ff;
            box-shadow: inset 4px 0 0 var(--app-blue);
            color: var(--app-blue);
        }

        .nav-link svg,
        .icon-badge svg,
        .date-chip svg,
        .sidebar-meta svg,
        .inline-icon svg,
        .direction-icon svg {
            fill: none;
            stroke: currentColor;
            stroke-linecap: round;
            stroke-linejoin: round;
            stroke-width: 2;
        }

        .nav-link svg {
            height: 24px;
            width: 24px;
        }

        .sidebar-meta .meta-row {
            align-items: center;
            display: flex;
            gap: 0.45rem;
        }

        .sidebar-meta svg {
            height: 18px;
            width: 18px;
        }

        h1, h2, h3, p {
            letter-spacing: 0;
        }

        h1 {
            color: var(--app-ink);
            font-size: 2.45rem !important;
            font-weight: 760 !important;
            line-height: 1.05 !important;
            margin: 0 !important;
            hyphens: none !important;
            overflow-wrap: normal !important;
            word-break: keep-all !important;
        }

        .app-topbar {
            align-items: center;
            display: flex;
            gap: 1rem;
        }

        .date-chip {
            align-items: center;
            color: #17233d;
            display: inline-flex;
            font-size: 1.02rem;
            gap: 0.5rem;
            justify-content: center;
            padding-top: 0.3rem;
            white-space: nowrap;
        }

        .date-chip svg {
            height: 20px;
            width: 20px;
        }

        .profile-caption {
            color: var(--app-muted);
            font-size: 0.78rem;
            margin-top: -0.35rem;
            text-align: right;
        }

        .breadcrumb {
            align-items: center;
            color: #33415f;
            display: flex;
            font-size: 1.02rem;
            gap: 0.85rem;
            margin: 1.25rem 0 1.45rem;
        }

        .breadcrumb a {
            color: #33415f;
            text-decoration: none;
        }

        .mock-card {
            background: rgba(255, 255, 255, 0.91);
            border: 1px solid var(--app-border);
            border-radius: 12px;
            box-shadow: 0 12px 30px rgba(31, 66, 130, 0.06);
            padding: 1.25rem 1.35rem;
            transition: border-color 160ms ease, box-shadow 160ms ease, transform 160ms ease;
        }

        .mock-card:hover {
            border-color: #bdd3ff;
            box-shadow: 0 16px 34px rgba(31, 66, 130, 0.1);
            transform: translateY(-1px);
        }

        [data-testid="stVerticalBlockBorderWrapper"] {
            background: rgba(255, 255, 255, 0.92);
            border: 1px solid var(--app-border);
            border-radius: 12px;
            box-shadow: 0 12px 30px rgba(31, 66, 130, 0.06);
            padding: 0.72rem 0.72rem 0.9rem;
            transition: border-color 160ms ease, box-shadow 160ms ease, transform 160ms ease;
        }

        [data-testid="stVerticalBlockBorderWrapper"]:hover {
            border-color: #bdd3ff;
            box-shadow: 0 16px 34px rgba(31, 66, 130, 0.1);
            transform: translateY(-1px);
        }

        .card-title {
            align-items: center;
            display: flex;
            gap: 0.9rem;
            margin-bottom: 1.08rem;
        }

        .card-title h2,
        .card-title h3 {
            font-size: 1.45rem !important;
            font-weight: 760 !important;
            margin: 0 !important;
        }

        .icon-badge {
            align-items: center;
            background: #eaf1ff;
            border-radius: 14px;
            color: var(--app-blue);
            display: inline-flex;
            font-size: 1.24rem;
            font-weight: 760;
            height: 48px;
            justify-content: center;
            width: 48px;
        }

        .icon-badge svg {
            height: 25px;
            width: 25px;
        }

        .icon-badge.orange {
            background: #fff2e6;
            color: var(--app-orange);
        }

        .count-badge {
            background: #fff0dd;
            border-radius: 10px;
            color: #df5600;
            font-weight: 760;
            margin-left: auto;
            min-width: 46px;
            padding: 0.47rem 0.72rem;
            text-align: center;
        }

        .period-tag {
            background: #e9efff;
            border-radius: 10px;
            color: var(--app-blue);
            display: inline-flex;
            font-size: 0.88rem;
            font-weight: 680;
            margin-left: 0.6rem;
            padding: 0.34rem 0.7rem;
            vertical-align: middle;
        }

        .status-badge {
            border-radius: 9px;
            display: inline-flex;
            font-size: 0.9rem;
            font-weight: 680;
            line-height: 1;
            padding: 0.45rem 0.62rem;
            white-space: nowrap;
        }

        .status-draft {
            background: #fff0df;
            color: #f06400;
        }

        .status-approved {
            background: #e8f3ff;
            color: #075dda;
        }

        .status-paid {
            background: #ddf6e5;
            color: #07833e;
        }

        .saldo-red {
            color: var(--app-red);
            font-weight: 680;
        }

        .saldo-green {
            color: var(--app-green);
            font-weight: 680;
        }

        .muted {
            color: #7886a3;
        }

        .hint-line {
            color: #75829e;
            font-size: 0.95rem;
            margin-top: 1.05rem;
        }

        .mock-table {
            border: 1px solid #dbe3f2;
            border-radius: 10px;
            margin-bottom: 0.35rem;
            overflow: hidden;
        }

        .table-head,
        .table-row {
            align-items: center;
            display: grid;
            gap: 0.7rem;
            min-height: 48px;
            padding: 0.62rem 1.15rem;
        }

        .table-head {
            background: rgba(250, 252, 255, 0.96);
            border-bottom: 1px solid #dbe3f2;
            color: #1b2742;
            font-size: 0.92rem;
            font-weight: 680;
        }

        .table-row {
            background: white;
            border-bottom: 1px solid #e5ebf5;
            color: #26334f;
            font-size: 0.95rem;
        }

        .table-head > span,
        .table-row > span,
        .table-row > strong {
            align-items: center;
            display: inline-flex;
            min-width: 0;
        }

        .table-row:last-child {
            border-bottom: 0;
        }

        .table-row:hover {
            background: #f8fbff;
        }

        .current-grid,
        .statement-grid {
            grid-template-columns: 0.65fr 0.9fr 1fr 1.15fr 1.1fr 0.9fr 0.9fr 0.95fr 0.85fr;
        }

        .draft-grid {
            grid-template-columns: 0.34fr 0.75fr 1fr 0.85fr 0.75fr;
        }

        .year-grid {
            grid-template-columns: 1.1fr 1.1fr 1fr 1fr;
        }

        .item-grid {
            grid-template-columns: minmax(168px, 1.55fr) 1.05fr 0.95fr 0.9fr 0.9fr 0.9fr;
        }

        .table-action-link {
            align-items: center;
            border: 1px solid #bfd5ff;
            border-radius: 7px;
            color: var(--app-blue) !important;
            display: inline-flex;
            font-size: 0.86rem;
            font-weight: 720;
            justify-content: center;
            line-height: 1;
            min-height: 2.05rem;
            padding: 0 0.62rem;
            text-decoration: none !important;
            transition: background 150ms ease, box-shadow 150ms ease, transform 150ms ease;
            white-space: nowrap;
        }

        .table-action-link:hover {
            background: #edf4ff;
            box-shadow: 0 6px 14px rgba(15, 98, 255, 0.13);
            transform: translateY(-1px);
        }

        .timeline {
            margin: 0.35rem 0 0.6rem 0.45rem;
            padding-left: 1.35rem;
            position: relative;
        }

        .timeline:before {
            background: #c7d1e0;
            bottom: 1.5rem;
            content: "";
            left: 0.24rem;
            position: absolute;
            top: 0.65rem;
            width: 2px;
        }

        .timeline-entry {
            margin-bottom: 1.55rem;
            position: relative;
        }

        .timeline-entry:before {
            background: var(--app-blue);
            border: 3px solid #eef4ff;
            border-radius: 99px;
            content: "";
            height: 12px;
            left: -1.42rem;
            position: absolute;
            top: 0.1rem;
            width: 12px;
        }

        .timeline-entry strong {
            color: var(--app-ink);
            display: block;
            font-weight: 760;
            margin-bottom: 0.42rem;
        }

        .timeline-meta {
            color: #41516f;
            display: grid;
            gap: 0.65rem;
            grid-template-columns: minmax(0, 1.2fr) minmax(0, 0.85fr);
        }

        .empty-clock {
            align-items: center;
            color: #7a8aaa;
            display: flex;
            flex-direction: column;
            gap: 0.8rem;
            justify-content: center;
            min-height: 180px;
            text-align: center;
        }

        .empty-clock .circle {
            align-items: center;
            background: #f1f4fa;
            border-radius: 50%;
            display: flex;
            font-size: 2.3rem;
            height: 86px;
            justify-content: center;
            width: 86px;
        }

        .empty-clock .circle svg {
            fill: none;
            height: 42px;
            stroke: currentColor;
            stroke-linecap: round;
            stroke-linejoin: round;
            stroke-width: 1.8;
            width: 42px;
        }

        .item-type {
            align-items: center;
            display: inline-flex;
            gap: 0.48rem;
            min-width: 0;
            white-space: nowrap;
        }

        .direction-icon {
            align-items: center;
            border-radius: 7px;
            display: inline-flex;
            flex: 0 0 auto;
            height: 26px;
            justify-content: center;
            width: 26px;
        }

        .direction-icon.output {
            background: #e4f8e9;
            color: #09923b;
        }

        .direction-icon.input {
            background: #fff0f0;
            color: #ff2525;
        }

        .direction-icon svg {
            height: 16px;
            width: 16px;
        }

        .stButton > button,
        [data-testid="stBaseButton-secondary"],
        [data-testid="stBaseButton-primary"] {
            border-radius: 8px !important;
            cursor: pointer;
            font-weight: 680 !important;
            min-height: 2.42rem;
            transition: transform 150ms ease, box-shadow 150ms ease, border-color 150ms ease, background 150ms ease;
        }

        .stButton > button:hover {
            border-color: #98baff !important;
            box-shadow: 0 8px 18px rgba(15, 98, 255, 0.14);
            transform: translateY(-1px);
        }

        .stButton > button[kind="primary"],
        [data-testid="stBaseButton-primary"] {
            background: linear-gradient(135deg, var(--app-blue), var(--app-blue-2)) !important;
            border-color: var(--app-blue) !important;
            color: white !important;
        }

        div[data-testid="stSelectbox"] div[data-baseweb="select"] > div {
            border-radius: 12px;
            cursor: pointer !important;
            min-height: 3rem;
        }

        div[data-testid="stSelectbox"],
        div[data-testid="stSelectbox"] *,
        div[data-baseweb="popover"] * {
            cursor: pointer !important;
        }

        div[data-testid="stSelectbox"] input {
            caret-color: transparent !important;
            pointer-events: none !important;
            user-select: none !important;
        }

        div[data-testid="stPopover"] button {
            border-radius: 8px;
        }

        div[role="dialog"]:has(.large-dialog) {
            left: 50% !important;
            margin: 0 !important;
            max-height: min(76vh, 720px) !important;
            max-width: min(1060px, calc(100vw - 4rem)) !important;
            overflow: auto !important;
            top: max(72px, 12vh) !important;
            transform: translateX(-50%) !important;
            width: min(1060px, calc(100vw - 4rem)) !important;
        }

        div[role="dialog"]:has(.large-dialog) [data-testid="stVerticalBlock"] {
            gap: 0.65rem;
        }

        @media (max-width: 900px) {
            .block-container {
                padding: 1.4rem 1rem 2rem 110px;
            }
            .app-sidebar {
                width: 92px;
            }
            h1 {
                font-size: 1.5rem !important;
            }
            .table-head,
            .table-row {
                overflow-x: auto;
            }
        }

        @media (max-width: 680px) {
            h1 {
                font-size: 1.28rem !important;
            }
            .date-chip {
                font-size: 0.84rem;
            }
        }
        </style>
        """,
        unsafe_allow_html=True,
    )


def render_sidebar(active: str) -> None:
    links = [
        ("overview", "Übersicht", "/Übersicht", "home"),
        ("new", "Neue Abrechnung", "/Neue_Abrechnung", "file-plus"),
        ("select", "Abrechnung auswählen", "/Abrechnung_auswählen", "folder"),
    ]
    nav_items = []
    for key, label, href, icon in links:
        active_class = " active" if key == active else ""
        nav_items.append(
            f'<a class="nav-link{active_class}" href="{href}" target="_self">'
            f'{icon_svg(icon)}<span>{html.escape(label)}</span></a>'
        )
    st.markdown(
        f"""
        <nav class="app-sidebar">
            <div class="logo-tile">%</div>
            {''.join(nav_items)}
            <div class="sidebar-meta">
                <div class="meta-row">{icon_svg("clock")}<span>Hilfe</span></div>
                <div class="meta-row">{icon_svg("log-out")}<span>Ausloggen</span></div>
            </div>
        </nav>
        """,
        unsafe_allow_html=True,
    )


def icon_svg(name: str, size: int | None = None) -> str:
    svg = ICONS.get(name, "")
    if not svg or size is None:
        return svg
    return svg.replace("<svg ", f'<svg width="{size}" height="{size}" ')


def icon_html(name: str) -> str:
    return ICONS.get(name, html.escape(name))


def current_date_label(today: date | None = None) -> str:
    return (today or date.today()).strftime("%d.%m.%Y")


def render_header(title: str, profiles: Iterable[vat.Fachkraft]) -> vat.Fachkraft:
    profiles = list(profiles)
    labels = [profile.label for profile in profiles]
    current = st.session_state.get("fachkraft_label", labels[0] if labels else "Fachkraft 1")
    index = labels.index(current) if current in labels else 0

    left, center, right = st.columns([5.4, 1.8, 2.2], vertical_alignment="center")
    with left:
        st.markdown(f"<h1>{html.escape(title)}</h1>", unsafe_allow_html=True)
    with center:
        st.markdown(
            f'<div class="date-chip">{icon_svg("calendar")} {html.escape(current_date_label())}</div>',
            unsafe_allow_html=True,
        )
    with right:
        selected = st.selectbox(
            "Fachkraft",
            labels,
            index=index,
            label_visibility="collapsed",
            key="fachkraft_label",
        )

    profile = next((item for item in profiles if item.label == selected), profiles[0])
    st.session_state["fachkraft_level"] = profile.level
    st.session_state["fachkraft_username"] = profile.username
    st.session_state["fachkraft_role"] = profile.role
    st.markdown(
        f'<div class="profile-caption">{html.escape(profile.role)} · {html.escape(profile.username)}</div>',
        unsafe_allow_html=True,
    )
    return profile


def render_breadcrumb(parts: list[str]) -> None:
    clean = [html.escape(part) for part in parts]
    text = ' <span class="muted">/</span> '.join(clean)
    st.markdown(
        f'<div class="breadcrumb"><span>&lt;</span><span>{text}</span></div>',
        unsafe_allow_html=True,
    )


def card_title(title: str, icon: str, badge: str | int | None = None, orange: bool = False) -> None:
    badge_html = ""
    if badge is not None:
        badge_html = f'<span class="count-badge">{html.escape(str(badge))}</span>'
    tone = " orange" if orange else ""
    st.markdown(
        f"""
        <div class="card-title">
            <span class="icon-badge{tone}">{icon_html(icon)}</span>
            <h2>{html.escape(title)}</h2>
            {badge_html}
        </div>
        """,
        unsafe_allow_html=True,
    )


def status_label(status: Any) -> str:
    if status is None or pd.isna(status):
        return "-"
    value = str(status).strip()
    return STATUS_LABELS.get(value, value or "-")


def status_badge(status: Any) -> str:
    value = "" if status is None or pd.isna(status) else str(status).strip()
    if not value or value == "-":
        return "-"
    tone = STATUS_TONES.get(value, "paid")
    return (
        f'<span class="status-badge status-{html.escape(tone)}">'
        f"{html.escape(status_label(value))}</span>"
    )


def type_label(vat_type: Any) -> str:
    if vat_type is None or pd.isna(vat_type):
        return "-"
    value = str(vat_type).strip()
    return VAT_TYPE_LABELS.get(value, value or "-")


def format_currency(value: Any) -> str:
    if value is None or pd.isna(value):
        return "-"
    try:
        amount = Decimal(str(value))
    except (InvalidOperation, ValueError):
        return f"{value} €"

    if amount == amount.to_integral_value():
        raw = f"{amount:,.0f}"
    else:
        raw = f"{amount:,.2f}"
    return raw.replace(",", "X").replace(".", ",").replace("X", ".") + " €"


def format_currency_zero(value: Any) -> str:
    if value is None or pd.isna(value) or str(value).strip() in {"", "-", "."}:
        return "0 €"
    return format_currency(value)


def format_date(value: Any, with_time: bool = False) -> str:
    if value is None or pd.isna(value) or value == "":
        return "-"
    try:
        timestamp = pd.to_datetime(value)
    except (TypeError, ValueError):
        return str(value)
    if with_time:
        return timestamp.strftime("%d.%m.%Y, %H:%M Uhr")
    return timestamp.strftime("%d.%m.%Y")


def format_id(value: Any) -> str:
    if value is None or pd.isna(value):
        return "-"
    return str(int(value))


def period_current() -> str:
    today = date.today()
    return f"{today.year:04d}-{today.month:02d}"


def statement_href(statement_id: Any) -> str:
    return f"/Abrechnung_auswählen?statement_id={format_id(statement_id)}"


def empty_statement_row() -> dict[str, Any]:
    return {
        "VAT_STATEMENT_ID": None,
        "VAT_PERIOD": None,
        "VAT_STATUS": None,
        "OUTPUT_VAT_TOTAL": None,
        "INPUT_VAT_TOTAL": None,
        "VAT_BALANCE": None,
        "VAT_TYPE": None,
        "CREATED_BY": None,
        "CREATED_AT": None,
        "APPROVED_BY": None,
        "APPROVED_AT": None,
        "CLOSED_BY": None,
        "CLOSED_AT": None,
    }


def sortable_statements(df: pd.DataFrame) -> pd.DataFrame:
    if df.empty:
        return df.copy()
    sorted_df = df.copy()
    sorted_df["_STATUS_ORDER"] = sorted_df["VAT_STATUS"].map(STATUS_ORDER).fillna(99)
    return sorted_df.sort_values(["VAT_PERIOD", "_STATUS_ORDER", "VAT_STATEMENT_ID"], ascending=[False, True, False])


def transition_allowed(transitions: pd.DataFrame, profile: vat.Fachkraft, old_status: str, new_status: str) -> bool:
    if transitions.empty:
        return False
    matches = transitions[
        (transitions["OLD_STATUS"].astype(str) == old_status)
        & (transitions["NEW_STATUS"].astype(str) == new_status)
        & (transitions["SECURITY_LEVEL"].astype(int) == int(profile.level))
    ]
    return not matches.empty


def can_edit_statement(row: pd.Series | dict[str, Any] | None, profile: vat.Fachkraft, transitions: pd.DataFrame) -> bool:
    if row is None:
        return False
    statement_id = row.get("VAT_STATEMENT_ID")
    if statement_id is None or pd.isna(statement_id):
        return False
    status = str(row.get("VAT_STATUS") or "")
    if status == "DRAFT":
        return profile.level == 1 or transition_allowed(transitions, profile, "DRAFT", "APPROVED")
    if status == "APPROVED":
        return transition_allowed(transitions, profile, "APPROVED", "DRAFT") or transition_allowed(
            transitions, profile, "APPROVED", "PAID"
        )
    return False


def value_class(vat_type: Any) -> str:
    if vat_type is None or pd.isna(vat_type):
        return ""
    value = str(vat_type)
    if value == "UEBERHANG":
        return "saldo-green"
    if value == "ZAHLLAST":
        return "saldo-red"
    return ""


def source_label(source_table: Any, is_correction: Any = False) -> str:
    source = "" if source_table is None or pd.isna(source_table) else str(source_table)
    if bool(is_correction):
        return "Korrektur"
    if "SUPPLIER" in source:
        return "Eingangsrechnung"
    if "PAYMENT" in source:
        return "Korrektur"
    return "Ausgangsrechnung"


HISTORY_LABELS = {
    "VAT_DRAFT_CREATED": "Entwurf erstellt",
    "VAT_CALCULATED": "Berechnung durchgeführt",
    "VAT_RECALCULATED": "Neu berechnet",
    "VAT_APPROVED": "Freigegeben",
    "VAT_REJECTED": "Zurückgewiesen",
    "VAT_PAID": "Bezahlt / abgeschlossen",
}


def build_timeline(
    head: pd.Series,
    items: pd.DataFrame | None = None,
    history: pd.DataFrame | None = None,
) -> list[dict[str, str]]:
    entries: list[dict[str, str]] = []

    if history is not None and not history.empty:
        for _, event in history.iterrows():
            event_type = str(event.get("EVENT_TYPE") or "")
            event_at = event.get("EVENT_AT")
            if not event_type or pd.isna(event_at):
                continue
            entries.append(
                {
                    "title": HISTORY_LABELS.get(event_type, event_type),
                    "time": format_date(event_at, with_time=True),
                    "user": str(event.get("EVENT_BY") or "-"),
                }
            )
        if entries:
            return entries

    if not pd.isna(head.get("CREATED_AT")):
        entries.append(
            {
                "title": "Entwurf erstellt",
                "time": format_date(head.get("CREATED_AT"), with_time=True),
                "user": str(head.get("CREATED_BY") or "-"),
            }
        )

    if items is not None and not items.empty and "CREATED_AT" in items:
        first_item_at = items["CREATED_AT"].dropna().min()
        first_item_user = "-"
        if not pd.isna(first_item_at):
            first_rows = items[items["CREATED_AT"] == first_item_at]
            if not first_rows.empty:
                first_item_user = str(first_rows.iloc[0].get("CREATED_BY") or head.get("CREATED_BY") or "-")
            entries.append(
                {
                    "title": "Berechnung durchgeführt",
                    "time": format_date(first_item_at, with_time=True),
                    "user": first_item_user,
                }
            )

    if not pd.isna(head.get("APPROVED_AT")):
        entries.append(
            {
                "title": "Freigegeben",
                "time": format_date(head.get("APPROVED_AT"), with_time=True),
                "user": str(head.get("APPROVED_BY") or "-"),
            }
        )

    if not pd.isna(head.get("CLOSED_AT")):
        entries.append(
            {
                "title": "Bezahlt / abgeschlossen",
                "time": format_date(head.get("CLOSED_AT"), with_time=True),
                "user": str(head.get("CLOSED_BY") or "-"),
            }
        )

    return entries


def render_timeline(entries: list[dict[str, str]]) -> None:
    if not entries:
        st.markdown(
            dedent(
                f"""
            <div class="empty-clock">
                <div class="circle">{icon_svg("clock")}</div>
                <div>Noch kein Verlauf vorhanden</div>
            </div>
            """
            ).strip(),
            unsafe_allow_html=True,
        )
        return

    items_html = []
    for entry in entries:
        items_html.append(
            dedent(
                f"""
            <div class="timeline-entry">
                <strong>{html.escape(entry["title"])}</strong>
                <div class="timeline-meta">
                    <span>{html.escape(entry["time"])}</span>
                    <span>{html.escape(entry["user"])}</span>
                </div>
            </div>
            """
            ).strip()
        )
    st.markdown(f'<div class="timeline">{"".join(items_html)}</div>', unsafe_allow_html=True)


def friendly_error_message(exc: Exception) -> str:
    raw = str(exc)
    lower = raw.lower()

    if "invalid object name" in lower:
        return "Ein erwartetes Datenbankobjekt ist in der APP-Datenbank nicht erreichbar."
    if "duplicate" in lower or "unique" in lower or "existiert bereits" in lower:
        return "Für diese Periode existiert bereits eine Umsatzsteuerabrechnung."
    if "50001" in raw or "periode" in lower and "nicht" in lower:
        return "Diese Periode ist nicht abrechenbar oder das Periodenformat ist ungültig."
    if "50002" in raw or "freigegeben" in lower or "abgeschlossen" in lower:
        return "Diese Abrechnung ist bereits freigegeben oder abgeschlossen."
    if "50010" in raw or "security" in lower or "berecht" in lower or "securitylevel" in lower:
        return "Die ausgewählte Fachkraft hat für diese Aktion nicht die benötigte Berechtigung."
    if "login" in lower or "password" in lower or "credential" in lower:
        return "Die APP-Datenbankverbindung konnte nicht hergestellt werden."
    return raw


@st.dialog("Hinweis")
def message_dialog(title: str, message: str) -> None:
    st.markdown(f"**{title}**")
    st.write(message)
    if st.button("Schließen", use_container_width=True):
        st.rerun()


def show_error_dialog(title: str, exc: Exception) -> None:
    message_dialog(title, friendly_error_message(exc))


@st.dialog("Alle Drafts")
def drafts_dialog(drafts: pd.DataFrame) -> None:
    if drafts.empty:
        st.info("Keine offenen Drafts vorhanden.")
        return
    for _, row in drafts.iterrows():
        cols = st.columns([1, 1.2, 1, 0.9], vertical_alignment="center")
        cols[0].write(format_id(row["VAT_STATEMENT_ID"]))
        cols[1].write(str(row["VAT_PERIOD"]))
        cols[2].markdown(status_badge(row["VAT_STATUS"]), unsafe_allow_html=True)
        if cols[3].button("Öffnen", key=f"draft-dialog-{row['VAT_STATEMENT_ID']}"):
            st.session_state["selected_statement_id"] = int(row["VAT_STATEMENT_ID"])
            st.switch_page("pages/3_Abrechnung_auswählen.py")


@st.dialog("Abrechnung existiert bereits")
def existing_statement_dialog(statement_id: int, period: str) -> None:
    st.write(f"Für die Periode {period} existiert bereits eine Abrechnung.")
    if st.button("Bestehende Abrechnung öffnen", type="primary", use_container_width=True):
        st.session_state["selected_statement_id"] = int(statement_id)
        st.switch_page("pages/3_Abrechnung_auswählen.py")


@st.dialog("Alle Positionen")
def positions_dialog(items: pd.DataFrame) -> None:
    st.markdown('<div class="large-dialog"></div>', unsafe_allow_html=True)
    render_item_rows(items, limit=None)


@st.dialog("Gesamter Verlauf")
def timeline_dialog(entries: list[dict[str, str]]) -> None:
    st.markdown('<div class="large-dialog"></div>', unsafe_allow_html=True)
    render_timeline(entries)


def yearly_summary(statements: pd.DataFrame) -> dict[str, Any]:
    if statements.empty:
        return {"output": Decimal("0"), "input": Decimal("0"), "balance": Decimal("0"), "type": "NEUTRAL"}
    output_total = statements["OUTPUT_VAT_TOTAL"].sum()
    input_total = statements["INPUT_VAT_TOTAL"].sum()
    balance = abs(output_total - input_total)
    if output_total > input_total:
        vat_type = "ZAHLLAST"
    elif input_total > output_total:
        vat_type = "UEBERHANG"
    else:
        vat_type = "NEUTRAL"
    return {"output": output_total, "input": input_total, "balance": balance, "type": vat_type}


def render_statement_header_table(row: dict[str, Any] | pd.Series, action: bool = False) -> None:
    action_col = "0.85fr" if action else "0fr"
    st.markdown(
        f"""
        <div class="mock-table">
            <div class="table-head current-grid" style="grid-template-columns: 0.7fr 1fr 1fr 1.25fr 1.2fr 1fr 1fr {action_col};">
                <span>ID</span><span>Periode</span><span>Status</span><span>Umsatzsteuer</span>
                <span>Vorsteuer</span><span>Saldo</span><span>Type</span><span></span>
            </div>
            <div class="table-row current-grid" style="grid-template-columns: 0.7fr 1fr 1fr 1.25fr 1.2fr 1fr 1fr {action_col};">
                <span>{html.escape(format_id(row.get("VAT_STATEMENT_ID")))}</span>
                <strong>{html.escape(str(row.get("VAT_PERIOD") or "-"))}</strong>
                <span>{status_badge(row.get("VAT_STATUS"))}</span>
                <span>{html.escape(format_currency(row.get("OUTPUT_VAT_TOTAL")))}</span>
                <span>{html.escape(format_currency(row.get("INPUT_VAT_TOTAL")))}</span>
                <span class="{value_class(row.get("VAT_TYPE"))}">{html.escape(format_currency(row.get("VAT_BALANCE")))}</span>
                <span class="{value_class(row.get("VAT_TYPE"))}">{html.escape(type_label(row.get("VAT_TYPE")))}</span>
                <span></span>
            </div>
        </div>
        """,
        unsafe_allow_html=True,
    )


def render_draft_rows(drafts: pd.DataFrame, key_prefix: str, limit: int = 2) -> None:
    shown = drafts.head(limit)
    rows = [
        dedent(
            """
        <div class="mock-table">
            <div class="table-head draft-grid">
                <span></span><span>ID</span><span>Periode</span><span>Status</span><span></span>
            </div>
        """
        ).strip()
    ]
    if shown.empty:
        rows.append("</div>")
        st.markdown("".join(rows), unsafe_allow_html=True)
        st.markdown('<div class="hint-line">Keine offenen Drafts vorhanden.</div>', unsafe_allow_html=True)
        return

    for _, row in shown.iterrows():
        rows.append(
            dedent(
                f"""
            <div class="table-row draft-grid">
                <span class="inline-icon">{icon_svg("document")}</span>
                <span>{html.escape(format_id(row["VAT_STATEMENT_ID"]))}</span>
                <span>{html.escape(str(row["VAT_PERIOD"]))}</span>
                <span>{status_badge(row["VAT_STATUS"])}</span>
                <span><a class="table-action-link" href="{html.escape(statement_href(row["VAT_STATEMENT_ID"]))}" target="_self">Öffnen</a></span>
            </div>
            """
            ).strip()
        )
    rows.append("</div>")
    st.markdown("".join(rows), unsafe_allow_html=True)


def render_compact_statement_rows(statements: pd.DataFrame, key_prefix: str, limit: int | None = None) -> None:
    data = statements if limit is None else statements.head(limit)
    if data.empty:
        st.info("Keine Abrechnungen vorhanden.")
        return
    for _, row in data.iterrows():
        cols = st.columns([0.7, 1, 1.1, 1, 1, 1, 0.85], vertical_alignment="center")
        cols[0].write(format_id(row["VAT_STATEMENT_ID"]))
        cols[1].write(str(row["VAT_PERIOD"]))
        cols[2].markdown(status_badge(row["VAT_STATUS"]), unsafe_allow_html=True)
        cols[3].write(format_currency(row["OUTPUT_VAT_TOTAL"]))
        cols[4].write(format_currency(row["INPUT_VAT_TOTAL"]))
        cols[5].markdown(
            f'<span class="{value_class(row["VAT_TYPE"])}">{html.escape(format_currency(row["VAT_BALANCE"]))}</span>',
            unsafe_allow_html=True,
        )
        if cols[6].button("Öffnen", key=f"{key_prefix}-{row['VAT_STATEMENT_ID']}"):
            st.session_state["selected_statement_id"] = int(row["VAT_STATEMENT_ID"])
            st.switch_page("pages/3_Abrechnung_auswählen.py")


def render_all_statement_rows(statements: pd.DataFrame, key_prefix: str) -> None:
    rows = [
        dedent(
            """
        <div class="mock-table">
            <div class="table-head statement-grid">
                <span>ID</span><span>Periode</span><span>Status</span><span>Umsatzsteuer</span>
                <span>Vorsteuer</span><span>Saldo</span><span>Type</span><span>Erstellt am</span><span>Aktion</span>
            </div>
        """
        ).strip()
    ]
    if statements.empty:
        rows.append("</div>")
        st.markdown("".join(rows), unsafe_allow_html=True)
        st.markdown('<div class="hint-line">Keine Umsatzsteuerabrechnungen vorhanden.</div>', unsafe_allow_html=True)
        return
    for _, row in statements.iterrows():
        value_tone = value_class(row["VAT_TYPE"])
        rows.append(
            dedent(
                f"""
            <div class="table-row statement-grid">
                <span>{html.escape(format_id(row["VAT_STATEMENT_ID"]))}</span>
                <span>{html.escape(str(row["VAT_PERIOD"]))}</span>
                <span>{status_badge(row["VAT_STATUS"])}</span>
                <span>{html.escape(format_currency(row["OUTPUT_VAT_TOTAL"]))}</span>
                <span>{html.escape(format_currency(row["INPUT_VAT_TOTAL"]))}</span>
                <span class="{html.escape(value_tone)}">{html.escape(format_currency(row["VAT_BALANCE"]))}</span>
                <span class="{html.escape(value_tone)}">{html.escape(type_label(row["VAT_TYPE"]))}</span>
                <span>{html.escape(format_date(row.get("CREATED_AT")))}</span>
                <span><a class="table-action-link" href="{html.escape(statement_href(row["VAT_STATEMENT_ID"]))}" target="_self">Öffnen</a></span>
            </div>
            """
            ).strip()
        )
    rows.append("</div>")
    st.markdown("".join(rows), unsafe_allow_html=True)


def render_item_rows(items: pd.DataFrame, limit: int | None = 4) -> None:
    data = items if limit is None else items.head(limit)
    rows = [
        dedent(
            """
        <div class="mock-table">
            <div class="table-head item-grid">
                <span>Art</span><span>Beleg</span><span>Datum</span><span>Netto</span><span>USt.</span><span>Brutto</span>
            </div>
        """
        ).strip()
    ]
    if data.empty:
        rows.append("</div>")
        st.markdown("".join(rows), unsafe_allow_html=True)
        st.markdown('<div class="hint-line">Keine Positionen vorhanden.</div>', unsafe_allow_html=True)
        return

    for _, row in data.iterrows():
        label = source_label(row["SOURCE_TABLE"], row.get("IS_CORRECTION"))
        is_input = label == "Eingangsrechnung"
        direction = "input" if is_input else "output"
        icon = "arrow-down" if is_input else "arrow-up"
        rows.append(
            dedent(
                f"""
            <div class="table-row item-grid">
                <span class="item-type"><span class="direction-icon {direction}">{icon_svg(icon)}</span>{html.escape(label)}</span>
                <span>{html.escape(str(row["SOURCE_INVOICE_ID"]))}</span>
                <span>{html.escape(format_date(row["SOURCE_INVOICE_DATE"]))}</span>
                <span>{html.escape(format_currency_zero(row.get("NET_AMOUNT")))}</span>
                <span>{html.escape(format_currency_zero(row.get("TAX_AMOUNT")))}</span>
                <span>{html.escape(format_currency_zero(row.get("GROSS_AMOUNT")))}</span>
            </div>
            """
            ).strip()
        )
    rows.append("</div>")
    st.markdown("".join(rows), unsafe_allow_html=True)
