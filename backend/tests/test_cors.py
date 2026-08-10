def test_cors_preflight_allowed(client):
    resp = client.options(
        "/api/v1/auth/login",
        headers={
            "Origin": "http://x.com",
            "Access-Control-Request-Method": "POST",
        },
    )
    assert resp.status_code == 200
    assert resp.headers.get("access-control-allow-origin") == "*"
