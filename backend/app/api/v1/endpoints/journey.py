import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_db
from app.core.deps import get_current_user
from app.models.user import User
from app.models.features import Journey
from app.schemas.features import JourneyCreate, JourneyUpdate, JourneyResponse

router = APIRouter()


def _get_active_journey(db: Session, user_id: uuid.UUID) -> Optional[Journey]:
    return (
        db.query(Journey)
        .filter(Journey.user_id == user_id, Journey.is_active == True)
        .order_by(Journey.created_at.desc())
        .first()
    )


@router.post("/start", response_model=JourneyResponse, status_code=status.HTTP_201_CREATED)
def start_journey(
    journey_in: JourneyCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Start a new journey."""
    # FIX: journeys could overlap without limit - the app has no way to know
    # which one is "the" active trip.
    existing = _get_active_journey(db, current_user.id)
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"An active journey already exists: {existing.id}",
        )

    journey = Journey(**journey_in.model_dump(), user_id=current_user.id)
    db.add(journey)
    db.commit()
    db.refresh(journey)
    return journey


# FIX: no way to restore trip state after the app is killed mid-journey -
# this is what AppService should poll on startup.
@router.get("/active", response_model=Optional[JourneyResponse])
def get_active_journey(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Retrieve the user's currently active journey, if any."""
    return _get_active_journey(db, current_user.id)


@router.get("", response_model=List[JourneyResponse])
@router.get("/", response_model=List[JourneyResponse], include_in_schema=False)
def list_journeys(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """List the user's journey history, newest first."""
    return (
        db.query(Journey)
        .filter(Journey.user_id == current_user.id)
        .order_by(Journey.created_at.desc())
        .all()
    )


@router.patch("/{journey_id}", response_model=JourneyResponse)
def update_journey(
    journey_id: uuid.UUID,
    journey_in: JourneyUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Update a journey (e.g. current location or status)."""
    journey = db.query(Journey).filter(Journey.id == journey_id, Journey.user_id == current_user.id).first()
    if not journey:
        raise HTTPException(status_code=404, detail="Journey not found")

    update_data = journey_in.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(journey, field, value)

    db.add(journey)
    db.commit()
    db.refresh(journey)
    return journey


# Deprecated alias kept for backwards compatibility - PATCH /{journey_id} is canonical.
@router.put("/{journey_id}/update", response_model=JourneyResponse, include_in_schema=False)
def update_journey_legacy(
    journey_id: uuid.UUID,
    journey_in: JourneyUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return update_journey(journey_id, journey_in, db, current_user)


@router.post("/{journey_id}/stop", response_model=JourneyResponse)
def stop_journey(
    journey_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Stop an active journey."""
    journey = db.query(Journey).filter(Journey.id == journey_id, Journey.user_id == current_user.id).first()
    if not journey:
        raise HTTPException(status_code=404, detail="Journey not found")

    if not journey.is_active:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Journey already stopped")

    journey.is_active = False
    db.add(journey)
    db.commit()
    db.refresh(journey)
    return journey
