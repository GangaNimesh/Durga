from typing import List, Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import get_db
from app.models.features import Helpline
from app.schemas.features import HelplineResponse

router = APIRouter()

# Fallback only - used when the helplines table is empty (fresh clone that
# hasn't run the seed script yet). The DB is the source of truth otherwise.
STATIC_HELPLINES = [
    {"id": "00000000-0000-0000-0000-000000000001", "name": "Women Helpline (All India)", "phone": "1091", "category": "Women Safety"},
    {"id": "00000000-0000-0000-0000-000000000002", "name": "Police", "phone": "100", "category": "General Emergency"},
    {"id": "00000000-0000-0000-0000-000000000003", "name": "National Emergency Number", "phone": "112", "category": "General Emergency"},
    {"id": "00000000-0000-0000-0000-000000000004", "name": "Domestic Abuse", "phone": "181", "category": "Women Safety"},
]


# FIX: the Helpline model and migration existed but this endpoint always
# returned a hardcoded Python list - the table was dead schema.
@router.get("", response_model=List[HelplineResponse])
@router.get("/", response_model=List[HelplineResponse], include_in_schema=False)
def get_helplines(
    category: Optional[str] = Query(None),
    db: Session = Depends(get_db),
):
    """Get the emergency helpline list, DB-backed with an optional category filter."""
    query = db.query(Helpline)
    if category:
        query = query.filter(Helpline.category == category)
    rows = query.order_by(Helpline.name).all()

    if rows:
        return rows

    if category:
        return [h for h in STATIC_HELPLINES if h["category"] == category]
    return STATIC_HELPLINES
