import os
import socket
from datetime import datetime, timezone

import pymysql
from flask import Flask, jsonify

app = Flask(__name__)

MYSQL_HOST = os.getenv("MYSQL_HOST", "mysql.database.svc.cluster.local")
MYSQL_PORT = int(os.getenv("MYSQL_PORT", "3306"))
MYSQL_DATABASE = os.getenv("MYSQL_DATABASE", "hello_db")
MYSQL_USER = os.getenv("MYSQL_USER", "hello_user")
MYSQL_PASSWORD = os.getenv("MYSQL_PASSWORD", "hello_password_123")
APP_VERSION = os.getenv("APP_VERSION", "bootstrap")


def get_connection():
    return pymysql.connect(
        host=MYSQL_HOST,
        port=MYSQL_PORT,
        user=MYSQL_USER,
        password=MYSQL_PASSWORD,
        database=MYSQL_DATABASE,
        connect_timeout=5,
        autocommit=True,
        cursorclass=pymysql.cursors.DictCursor,
    )


def ensure_schema():
    with get_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                CREATE TABLE IF NOT EXISTS visits (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    source VARCHAR(64) NOT NULL,
                    app_version VARCHAR(64) NOT NULL
                )
                """
            )


@app.get("/healthz")
def healthz():
    return jsonify(status="ok", service="backend", version=APP_VERSION)


@app.get("/api/status")
def status():
    try:
        ensure_schema()
        with get_connection() as connection:
            with connection.cursor() as cursor:
                cursor.execute("SELECT DATABASE() AS database_name, NOW() AS database_time")
                row = cursor.fetchone()
        return jsonify(
            status="ok",
            service="backend",
            hostname=socket.gethostname(),
            version=APP_VERSION,
            mysql={
                "reachable": True,
                "host": MYSQL_HOST,
                "database": row["database_name"],
                "time": str(row["database_time"]),
            },
        )
    except Exception as exc:
        return jsonify(
            status="degraded",
            service="backend",
            hostname=socket.gethostname(),
            version=APP_VERSION,
            mysql={"reachable": False, "host": MYSQL_HOST, "error": str(exc)},
        ), 503


@app.post("/api/visits")
@app.get("/api/visits")
def visits():
    ensure_schema()
    with get_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                "INSERT INTO visits(source, app_version) VALUES (%s, %s)",
                (socket.gethostname(), APP_VERSION),
            )
            cursor.execute("SELECT COUNT(*) AS total FROM visits")
            total = cursor.fetchone()["total"]
    return jsonify(
        status="ok",
        total_visits=total,
        inserted_at=datetime.now(timezone.utc).isoformat(),
        backend_pod=socket.gethostname(),
        version=APP_VERSION,
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
