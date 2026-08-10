def test_timestamps_are_utc_aware(client, auth_headers):
    resp = client.get("/api/v1/auth/me", headers=auth_headers)
    assert resp.status_code == 200
    assert resp.json()["created_at"].endswith("+00:00")
