def test_sos_last_returns_null_when_empty(client, auth_headers):
    resp = client.get("/api/v1/sos/last", headers=auth_headers)
    assert resp.status_code == 200
    assert resp.json() is None


def test_sos_trigger_then_resolve(client, auth_headers):
    trigger = client.post(
        "/api/v1/sos/trigger",
        headers=auth_headers,
        json={"latitude": 12.9, "longitude": 77.6},
    )
    assert trigger.status_code == 201
    sos_id = trigger.json()["id"]

    last = client.get("/api/v1/sos/last", headers=auth_headers)
    assert last.json()["id"] == sos_id

    resolve = client.post(f"/api/v1/sos/{sos_id}/resolve", headers=auth_headers)
    assert resolve.status_code == 200
    assert resolve.json()["is_active"] is False

    last_after = client.get("/api/v1/sos/last", headers=auth_headers)
    assert last_after.json() is None
