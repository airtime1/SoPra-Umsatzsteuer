"""
Datenbank-Wrapper. Liest Credentials aus .env und stellt drei Connections bereit:

- get_app_conn():     ueber ERP_REMOTE_USER (read/write/execute). Fuer das laufende UI.
- get_dev_conn():     persoenlicher User auf ERPDEV26S. Nur fuer Analyse/Deploy-Skripte.
- get_sandbox_conn(): eigene Sandbox. Fuer lokale Deploys und Tests.

Alle Aufrufe an Stored Procedures / Functions laufen ueber kleine Helper, damit die UI nicht
direkt mit pyodbc-Cursor-Code hantieren muss.
"""

from __future__ import annotations

import os
from contextlib import contextmanager
from typing import Iterator

import pyodbc
from dotenv import load_dotenv

load_dotenv()


def _build_conn_str(server: str, database: str, user: str, password: str) -> str:
    driver = os.getenv("ODBC_DRIVER", "ODBC Driver 17 for SQL Server")
    parts = [
        f"DRIVER={{{driver}}}",
        f"SERVER={server}",
        f"DATABASE={database}",
        f"UID={user}",
        f"PWD={password}",
        "TrustServerCertificate=yes",
    ]
    # FreeTDS (Linux / Streamlit Cloud) braucht einen expliziten Port und die
    # TDS-Protokollversion. Lokal mit dem Microsoft-ODBC-Treiber bleibt der
    # String unveraendert (diese Keywords werden dort nicht ergaenzt).
    if "tdsodbc" in driver.lower() or driver.lower() == "freetds":
        parts.append(f"PORT={os.getenv('DB_PORT', '1433')}")
        parts.append("TDS_Version=7.4")
    return ";".join(parts) + ";"


def _conn(prefix: str) -> pyodbc.Connection:
    """Build a connection using the env vars with the given prefix (DEV, SANDBOX, APP)."""
    server = os.environ[f"{prefix}_SERVER"]
    database = os.environ[f"{prefix}_DATABASE"]
    user = os.environ[f"{prefix}_USER"]
    password = os.environ[f"{prefix}_PASSWORD"]
    return pyodbc.connect(_build_conn_str(server, database, user, password))


@contextmanager
def get_app_conn() -> Iterator[pyodbc.Connection]:
    """Frontend-Connection mit ERP_REMOTE_USER."""
    conn = _conn("APP")
    try:
        yield conn
    finally:
        conn.close()


@contextmanager
def get_dev_conn() -> Iterator[pyodbc.Connection]:
    """Persoenliche Dev-Connection auf ERPDEV26S. Fuer Deploy-Skripte."""
    conn = _conn("DEV")
    try:
        yield conn
    finally:
        conn.close()


@contextmanager
def get_sandbox_conn() -> Iterator[pyodbc.Connection]:
    """Eigene Sandbox. Fuer lokale Tests."""
    conn = _conn("SANDBOX")
    try:
        yield conn
    finally:
        conn.close()


@contextmanager
def get_active_conn() -> Iterator[pyodbc.Connection]:
    """DB-Connection fuer die App, gesteuert ueber APP_DB_PROFILE."""
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
