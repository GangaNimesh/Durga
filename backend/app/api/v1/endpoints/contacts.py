import uuid
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_db
from app.core.deps import get_current_user
from app.models.user import User
from app.models.features import Contact
from app.schemas.features import ContactCreate, ContactUpdate, ContactResponse

router = APIRouter()

MAX_CONTACTS_PER_USER = 10

# FIX: routes were registered as "/" only, so a client requesting "/contacts"
# (no trailing slash) got a 307 redirect. Harmless on curl, fatal on Flutter
# Web where browsers refuse to follow redirects during a CORS preflight.
@router.get("", response_model=List[ContactResponse])
@router.get("/", response_model=List[ContactResponse], include_in_schema=False)
def get_contacts(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Retrieve all contacts for the current user."""
    contacts = db.query(Contact).filter(Contact.user_id == current_user.id).all()
    return contacts

@router.post("", response_model=ContactResponse, status_code=status.HTTP_201_CREATED)
@router.post("/", response_model=ContactResponse, status_code=status.HTTP_201_CREATED, include_in_schema=False)
def create_contact(
    contact_in: ContactCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Create a new contact."""
    existing_count = db.query(Contact).filter(Contact.user_id == current_user.id).count()
    if existing_count >= MAX_CONTACTS_PER_USER:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Maximum of {MAX_CONTACTS_PER_USER} emergency contacts reached",
        )

    dup = db.query(Contact).filter(
        Contact.user_id == current_user.id, Contact.phone == contact_in.phone
    ).first()
    if dup:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Contact with this phone number already exists")

    contact = Contact(**contact_in.model_dump(), user_id=current_user.id)
    db.add(contact)
    db.commit()
    db.refresh(contact)
    return contact

# FIX: ContactUpdate previously inherited required fields from ContactBase,
# so exclude_unset=True was dead code - {"name": "X"} alone 422'd. Now that
# ContactUpdate is a standalone all-Optional model, PATCH does a real partial update.
@router.patch("/{contact_id}", response_model=ContactResponse)
def update_contact(
    contact_id: uuid.UUID,
    contact_in: ContactUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Update a contact."""
    contact = db.query(Contact).filter(Contact.id == contact_id, Contact.user_id == current_user.id).first()
    if not contact:
        raise HTTPException(status_code=404, detail="Contact not found")
    
    update_data = contact_in.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(contact, field, value)
        
    db.add(contact)
    db.commit()
    db.refresh(contact)
    return contact

@router.delete("/{contact_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_contact(
    contact_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Delete a contact."""
    contact = db.query(Contact).filter(Contact.id == contact_id, Contact.user_id == current_user.id).first()
    if not contact:
        raise HTTPException(status_code=404, detail="Contact not found")
        
    db.delete(contact)
    db.commit()
    return None
