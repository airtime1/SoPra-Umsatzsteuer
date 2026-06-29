"""
Datenbank-Wrapper. Liest Credentials aus .env und stellt drei Connections bereit:

- get_app_conn():     ueber ERP_REMOTE_USER. Fuer das laufende UI. Nutzt **pymssql**
                      (reiner Python-Treiber, kein System-ODBC-Treiber noetig ->
                      laeuft auf Streamlit Community Cloud ohne packages.txt).
- get_dev_conn():     persoenlicher User auf ERPDEV26S. Nur fuer Analyse/Deploy-Skripte (pyodbc).
- get_sandbox_conn(): eigene Sandbox. Fuer lokale Deploys und Tests (pyodbc).

Hinweis: Die UI-Service-Schicht (app/services/vat.py) ist auf den pymssql-Platzhalter
%s ausgelegt und nutzt die APP-Connection. Die Deploy-/Analyse-Skripte nutzen weiter
pyodbc (qmark `?`).
"""

from __future__ import annotations

import os
from contextlib import contextmanager
from typing import Iterator

import pymssql
import pyodbc
from dotenv import load_dotenv

load_dotenv()


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
def get_app_conn() -> Iterator["pymssql.Connection"]:
    """Frontend-Connection mit ERP_REMOTE_USER ueber pymssql."""
    conn = pymssql.connect(
        server=os.environ["APP_SERVER"],
        port=int(os.getenv("DB_PORT", "1433")),
        user=os.environ["APP_USER"],
        password=os.environ["APP_PASSWORD"],
        database=os.environ["APP_DATABASE"],
    )
    try:
        yield conn
    finally:
        conn.close()


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


@contextmanager
def get_active_conn() -> Iterator[object]:
    """DB-Connection fuer die App, gesteuert ueber APP_DB_PROFILE.

    Default `app` -> pymssql. `dev`/`sandbox` nutzen pyodbc und sind nur fuer
    lokale Hilfszwecke gedacht (die vat.py-Queries sind auf pymssql/%s ausgelegt).
    """
    profile = os.getenv("APP_DB_PROFILE", "app").strip().lower()
    connections = {
        "app": get_app_conn,
        "dev": get_dev_conn,
        "sandbox": get_sandbox_conn,
    }

    if profile not in connections:
        allowed = ", ".join(sorted(connections))
        raise ValueError(
            f"Unbekanntes APP_DB_PROFILE '{profile}'. Erlaubte Werte: {allowed}."
        )

    with connections[profile]() as conn:
        yield conn
