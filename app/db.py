"""
Datenbank-Wrapper. Liest Zielsysteme aus .env und stellt Connections bereit:

- get_user_conn():    echter DB-User aus dem Streamlit-Login. Fuer das laufende UI.
                      Nutzt **pymssql** (reiner Python-Treiber, kein System-ODBC).
- get_dev_conn():     persoenlicher User auf ERPDEV26S. Nur fuer Analyse/Deploy-Skripte (pyodbc).
- get_sandbox_conn(): eigene Sandbox. Fuer lokale Deploys und Tests (pyodbc).

Die UI-Service-Schicht (app/services/vat.py) ist auf den pymssql-Platzhalter
%s ausgelegt. Die Deploy-/Analyse-Skripte nutzen weiter pyodbc (qmark `?`).
"""

from __future__ import annotations

import os
from contextlib import contextmanager
from typing import Iterator

import pymssql
import pyodbc
from dotenv import load_dotenv

load_dotenv()


SESSION_USERNAME_KEY = "db_username"
SESSION_PASSWORD_KEY = "db_password"


def _build_conn_str(server: str, database: str, user: str, password: str) -> str:
    driver = os.getenv("ODBC_DRIVER", "ODBC Driver 17 for SQL Server")
    return (
        f"DRIVER={{{driver}}};"
        f"SERVER={server};"
        f"DATABASE={database};"
        f"UID={user};"
        f"PWD={password};"
        "TrustServerCertificate=yes;"
    )


def _pyodbc_conn(prefix: str) -> pyodbc.Connection:
    """pyodbc-Connection ueber die env vars mit dem gegebenen Prefix (DEV, SANDBOX)."""
    server = os.environ[f"{prefix}_SERVER"]
    database = os.environ[f"{prefix}_DATABASE"]
    user = os.environ[f"{prefix}_USER"]
    password = os.environ[f"{prefix}_PASSWORD"]
    return pyodbc.connect(_build_conn_str(server, database, user, password))


@contextmanager
def get_user_conn(username: str, password: str) -> Iterator["pymssql.Connection"]:
    """Frontend-Connection mit den echten DB-Credentials des eingeloggten Users."""
    conn = pymssql.connect(
        server=os.environ["APP_SERVER"],
        port=int(os.getenv("DB_PORT", "1433")),
        user=username,
        password=password,
        database=os.environ["APP_DATABASE"],
    )
    try:
        yield conn
    finally:
        conn.close()


@contextmanager
def get_authenticated_conn() -> Iterator["pymssql.Connection"]:
    """Streamlit-Session-Connection des eingeloggten DB-Users."""
    import streamlit as st

    username = st.session_state.get(SESSION_USERNAME_KEY)
    password = st.session_state.get(SESSION_PASSWORD_KEY)
    if not username or not password:
        raise RuntimeError("Nicht angemeldet. Bitte zuerst mit DB-Zugangsdaten anmelden.")

    with get_user_conn(str(username), str(password)) as conn:
        yield conn


@contextmanager
def get_dev_conn() -> Iterator[pyodbc.Connection]:
    """Persoenliche Dev-Connection auf ERPDEV26S. Fuer Deploy-Skripte."""
    conn = _pyodbc_conn("DEV")
    try:
        yield conn
    finally:
        conn.close()


@contextmanager
def get_sandbox_conn() -> Iterator[pyodbc.Connection]:
    """Eigene Sandbox. Fuer lokale Tests."""
    conn = _pyodbc_conn("SANDBOX")
    try:
        yield conn
    finally:
        conn.close()
