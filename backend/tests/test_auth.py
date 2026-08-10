from .conftest import register_and_login


def test_register_rejects_invalid_email(client):
    resp = client.post(
        "/api/v1/auth/register",
        json={
            "email": "not-an-email",
            "password": "pass1234",
            "full_name": "X",
            "phone": "+911234567890",
        },
    )
    assert resp.status_code == 422


def test_register_then_login_succeeds(client):
    headers = register_and_login(client)
    resp = client.get("/api/v1/auth/me", headers=headers)
    assert resp.status_code == 200
    assert resp.json()["email"] == "user@example.com"


def test_login_wrong_password_is_401(client):
    register_and_login(client)
    resp = client.post(
        "/api/v1/auth/login",
        json={"email": "user@example.com", "password": "wrongpass1"},
    )
    assert resp.status_code == 401


def test_no_auth_header_is_401_with_www_authenticate(client):
    resp = client.get("/api/v1/contacts")
    assert resp.status_code == 401
    assert resp.headers.get("www-authenticate") == "Bearer"


def test_login_rate_limited(client):
    register_and_login(client)
    for _ in range(10):
        client.post(
            "/api/v1/auth/login",
            json={"email": "user@example.com", "password": "wrongpass1"},
        )
    resp = client.post(
        "/api/v1/auth/login",
        json={"email": "user@example.com", "password": "wrongpass1"},
    )
    assert resp.status_code == 429
