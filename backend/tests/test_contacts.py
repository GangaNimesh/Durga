from .conftest import register_and_login


def test_contacts_no_trailing_slash_redirect(client, auth_headers):
    resp = client.get(
        "/api/v1/contacts", headers=auth_headers, follow_redirects=False
    )
    assert resp.status_code == 200


def test_partial_contact_update(client, auth_headers):
    create = client.post(
        "/api/v1/contacts",
        headers=auth_headers,
        json={"name": "Mummy", "phone": "+911111111111"},
    )
    assert create.status_code == 201
    contact_id = create.json()["id"]

    resp = client.patch(
        f"/api/v1/contacts/{contact_id}",
        headers=auth_headers,
        json={"name": "Mummy2"},
    )
    assert resp.status_code == 200
    assert resp.json()["name"] == "Mummy2"
    assert resp.json()["phone"] == "+911111111111"


def test_duplicate_contact_phone_is_409(client, auth_headers):
    client.post(
        "/api/v1/contacts",
        headers=auth_headers,
        json={"name": "A", "phone": "+911111111111"},
    )
    resp = client.post(
        "/api/v1/contacts",
        headers=auth_headers,
        json={"name": "B", "phone": "+911111111111"},
    )
    assert resp.status_code == 409


def test_cannot_read_another_users_contacts(client, auth_headers):
    client.post(
        "/api/v1/contacts",
        headers=auth_headers,
        json={"name": "Mine", "phone": "+911111111111"},
    )

    other_headers = register_and_login(
        client, email="other@example.com", password="pass5678"
    )
    resp = client.get("/api/v1/contacts", headers=other_headers)
    assert resp.status_code == 200
    assert resp.json() == []
