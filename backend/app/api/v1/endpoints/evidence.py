import uuid
from pathlib import Path
from typing import List

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, status
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from app.api.deps import get_db
from app.config import get_settings
from app.core.deps import get_current_user
from app.models.user import User
from app.models.features import Evidence
from app.schemas.features import EvidenceResponse

router = APIRouter()
settings = get_settings()

# FIX: os.makedirs(UPLOAD_DIR) ran at import time against a relative path,
# so the upload location depended on the shell's cwd. Anchor to the backend
# package so it's the same regardless of where uvicorn is launched from.
BACKEND_ROOT = Path(__file__).resolve().parents[4]
UPLOAD_DIR = BACKEND_ROOT / settings.UPLOAD_DIR
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

# FIX: extension was derived from the client-supplied filename via
# os.path.splitext, which raises TypeError when filename is None (some
# browsers / Dio MultipartFile calls send none) and trusts client input for
# something that ends up in a server-side path. Derive from our own MIME map.
ALLOWED_CONTENT_TYPES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "image/heic": ".heic",
    "video/mp4": ".mp4",
    "video/quicktime": ".mov",
    "video/mpeg": ".mpeg",
    "audio/mp4": ".m4a",
    "audio/aac": ".aac",
    "audio/wav": ".wav",
}

CHUNK_SIZE = 1024 * 1024  # 1 MB


@router.post("/upload", response_model=EvidenceResponse, status_code=status.HTTP_201_CREATED)
async def upload_evidence(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Upload evidence to local disk (mocking cloud upload) and record to DB."""
    extension = ALLOWED_CONTENT_TYPES.get(file.content_type)
    if extension is None:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=f"Unsupported content type: {file.content_type}",
        )

    filename = f"{uuid.uuid4()}{extension}"
    dest_path = UPLOAD_DIR / filename

    bytes_written = 0
    try:
        with open(dest_path, "wb") as buffer:
            while chunk := await file.read(CHUNK_SIZE):
                bytes_written += len(chunk)
                if bytes_written > settings.MAX_UPLOAD_BYTES:
                    buffer.close()
                    dest_path.unlink(missing_ok=True)
                    raise HTTPException(
                        status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                        detail=f"File exceeds the {settings.MAX_UPLOAD_BYTES} byte limit",
                    )
                buffer.write(chunk)
    except HTTPException:
        raise
    except Exception:
        dest_path.unlink(missing_ok=True)
        raise HTTPException(status_code=500, detail="Could not save file")

    if bytes_written == 0:
        dest_path.unlink(missing_ok=True)
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Empty file upload rejected")

    # FIX: file_path used to store the full absolute server path and return
    # it to the client - an information leak. Store only the opaque filename.
    evidence = Evidence(
        user_id=current_user.id,
        file_path=filename,
        file_type=file.content_type,
    )
    db.add(evidence)
    db.commit()
    db.refresh(evidence)
    return evidence


@router.get("", response_model=List[EvidenceResponse])
@router.get("/", response_model=List[EvidenceResponse], include_in_schema=False)
def list_evidence(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """List the current user's uploaded evidence."""
    return (
        db.query(Evidence)
        .filter(Evidence.user_id == current_user.id)
        .order_by(Evidence.created_at.desc())
        .all()
    )


def _resolve_owned_evidence(db: Session, evidence_id: uuid.UUID, user_id: uuid.UUID) -> Evidence:
    evidence = db.query(Evidence).filter(
        Evidence.id == evidence_id, Evidence.user_id == user_id
    ).first()
    if not evidence:
        raise HTTPException(status_code=404, detail="Evidence not found")
    return evidence


@router.get("/{evidence_id}/download")
def download_evidence(
    evidence_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Download a piece of evidence. Ownership-checked."""
    evidence = _resolve_owned_evidence(db, evidence_id, current_user.id)

    file_path = (UPLOAD_DIR / evidence.file_path).resolve()
    # Defence in depth against path traversal, even though file_path is
    # always a server-generated opaque filename.
    if not str(file_path).startswith(str(UPLOAD_DIR.resolve())) or not file_path.is_file():
        raise HTTPException(status_code=404, detail="Evidence file missing on disk")

    return FileResponse(file_path, media_type=evidence.file_type)


@router.delete("/{evidence_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_evidence(
    evidence_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Delete evidence - removes both the DB row and the file on disk."""
    evidence = _resolve_owned_evidence(db, evidence_id, current_user.id)

    file_path = UPLOAD_DIR / evidence.file_path
    file_path.unlink(missing_ok=True)

    db.delete(evidence)
    db.commit()
    return None
