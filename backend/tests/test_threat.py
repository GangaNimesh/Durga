def test_threat_ordinary_text_is_low_risk(client):
    resp = client.post("/api/v1/threat/analyze", json={"text": "hi"})
    assert resp.status_code == 200
    assert resp.json()["risk_level"] == "Low Risk"


def test_threat_word_boundary_not_substring(client):
    resp = client.post(
        "/api/v1/threat/analyze", json={"text": "this shelter is helpful"}
    )
    assert resp.json()["risk_level"] == "Low Risk"


def test_threat_high_risk_keyword(client):
    resp = client.post(
        "/api/v1/threat/analyze", json={"text": "someone is following me, danger"}
    )
    assert resp.json()["risk_level"] == "High Risk"


def test_threat_works_without_auth(client):
    resp = client.post("/api/v1/threat/analyze", json={"text": "test"})
    assert resp.status_code == 200
