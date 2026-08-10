import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.deps import get_db
from app.core.deps import get_current_user
from app.models.user import User
from app.models.features import SOSAlert
from app.schemas.features import SOSAlertCreate, SOSAlertResponse

router = APIRouter()


@router.post("/trigger", response_model=SOSAlertResponse, status_code=status.HTTP_201_CREATED)
def trigger_sos(
    sos_in: SOSAlertCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Trigger an SOS alert and (mock) send FCM push."""
    sos = SOSAlert(**sos_in.model_dump(), user_id=current_user.id, is_active=True)
    db.add(sos)
    db.commit()
    db.refresh(sos)
    # TODO: Native FCM push implementation here in the future - unimplemented.
    return sos


# FIX: response_model was the non-optional SOSAlertResponse, but the handler
# returns None for a user with no active alert -> ResponseValidationError -> 500.
# "No active emergency" is a normal state, not an error - 200 + null is correct.
@router.get("/last", response_model=Optional[SOSAlertResponse])
def get_last_sos(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Retrieve the most recent active SOS alert for the user."""
    sos = db.query(SOSAlert).filter(
        SOSAlert.user_id == current_user.id,
        SOSAlert.is_active == True
    ).order_by(SOSAlert.created_at.desc()).first()
    return sos


@router.get("/history", response_model=List[SOSAlertResponse])
def get_sos_history(
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """List the user's SOS alerts, newest first."""
    return (
        db.query(SOSAlert)
        .filter(SOSAlert.user_id == current_user.id)
        .order_by(SOSAlert.created_at.desc())
        .limit(limit)
        .all()
    )


# FIX: nothing ever cleared is_active, so /sos/last returned the user's
# first-ever alert forever. This is how the app marks an emergency resolved.
@router.post("/{sos_id}/resolve", response_model=SOSAlertResponse)
def resolve_sos(
    sos_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Mark an SOS alert as resolved (no longer active)."""
    sos = db.query(SOSAlert).filter(
        SOSAlert.id == sos_id, SOSAlert.user_id == current_user.id
    ).first()
    if not sos:
        raise HTTPException(status_code=404, detail="SOS alert not found")

    sos.is_active = False
    db.add(sos)
    db.commit()
    db.refresh(sos)
    return sos
