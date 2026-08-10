import os
import uuid

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event
from sqlalchemy.engine import Engine
from sqlalchemy.orm import sessionmaker

os.environ.setdefault("SECRET_KEY", "test-only-secret-key")
# The app's own lifespan (app/main.py) creates tables on its global engine
# regardless of per-test dependency overrides - point it at a throwaway file
# so tests never touch a developer's real durga.db.
os.environ.setdefault("DATABASE_URL", "sqlite:///./test_lifespan.db")

import app.models  # noqa: E402,F401 - registers all models on Base.metadata
from app.database import Base, get_db  # noqa: E402
from app.main import app  # noqa: E402 - must import last: rebinds `app` from package to FastAPI instance


@pytest.fixture()
def db_session(tmp_path):
    db_path = tmp_path / f"test_{uuid.uuid4().hex}.db"
    engine = create_engine(
        f"sqlite:///{db_path}", connect_args={"check_same_thread": False}
    )

    @event.listens_for(Engine, "connect")
    def _enable_foreign_keys(dbapi_connection, connection_record):
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()

    Base.metadata.create_all(bind=engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(bind=engine)


@pytest.fixture()
def client(db_session):
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db

    # The login rate limiter is process-global, in-memory state (by design -
    # see app/api/v1/endpoints/auth.py). Reset it per test so one test's
    # login attempts don't trip another test's rate limit.
    from app.api.v1.endpoints.auth import _LOGIN_ATTEMPTS
    _LOGIN_ATTEMPTS.clear()

    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


def register_and_login(client, email="user@example.com", password="pass1234"):
    client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": password,
            "full_name": "Test User",
            "phone": "+911234567890",
        },
    )
    resp = client.post(
        "/api/v1/auth/login", json={"email": email, "password": password}
    )
    token = resp.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture()
def auth_headers(client):
    return register_and_login(client)
