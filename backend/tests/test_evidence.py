import io

from app.config import get_settings


def test_upload_rejects_bad_mime(client, auth_headers):
    resp = client.post(
        "/api/v1/evidence/upload",
        headers=auth_headers,
        files={"file": ("bad.exe", io.BytesIO(b"content"), "application/x-msdownload")},
    )
    assert resp.status_code == 415


def test_upload_rejects_zero_byte(client, auth_headers):
    resp = client.post(
        "/api/v1/evidence/upload",
        headers=auth_headers,
        files={"file": ("empty.jpg", io.BytesIO(b""), "image/jpeg")},
    )
    assert resp.status_code == 400


def test_upload_rejects_oversize(client, auth_headers, monkeypatch):
    # NOTE: get_settings() is lru_cache'd, so this mutates the same Settings
    # instance every module in the app already holds a reference to.
    settings = get_settings()
    monkeypatch.setattr(settings, "MAX_UPLOAD_BYTES", 10)

    big_content = b"x" * 1000
    resp = client.post(
        "/api/v1/evidence/upload",
        headers=auth_headers,
        files={"file": ("big.jpg", io.BytesIO(big_content), "image/jpeg")},
    )
    assert resp.status_code == 413


def test_upload_then_list_download_delete(client, auth_headers):
    upload = client.post(
        "/api/v1/evidence/upload",
        headers=auth_headers,
        files={"file": ("good.jpg", io.BytesIO(b"fakejpegdata"), "image/jpeg")},
    )
    assert upload.status_code == 201
    evidence_id = upload.json()["id"]

    listing = client.get("/api/v1/evidence", headers=auth_headers)
    assert listing.status_code == 200
    assert len(listing.json()) == 1

    download = client.get(f"/api/v1/evidence/{evidence_id}/download", headers=auth_headers)
    assert download.status_code == 200

    delete = client.delete(f"/api/v1/evidence/{evidence_id}", headers=auth_headers)
    assert delete.status_code == 204
