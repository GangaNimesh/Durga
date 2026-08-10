"""Idempotent seed for the helplines table. Run with: python -m scripts.seed_helplines"""
from app.database import Base, SessionLocal, engine
from app.models.features import Helpline
import app.models  # noqa: F401 - registers all models on Base.metadata

HELPLINES = [
    {"name": "National Emergency Number", "phone": "112", "category": "General Emergency"},
    {"name": "Police", "phone": "100", "category": "General Emergency"},
    {"name": "Ambulance", "phone": "101", "category": "Medical Emergency"},
    {"name": "Ambulance (Medical)", "phone": "108", "category": "Medical Emergency"},
    {"name": "Women Helpline (All India)", "phone": "1091", "category": "Women Safety"},
    {"name": "Domestic Abuse", "phone": "181", "category": "Women Safety"},
    {"name": "Child Helpline", "phone": "1098", "category": "Child Safety"},
    {"name": "Cyber Crime", "phone": "1930", "category": "Cyber Safety"},
    {"name": "Senior Citizen Helpline", "phone": "14567", "category": "Elder Safety"},
    {"name": "Anti Poison", "phone": "182", "category": "Medical Emergency"},
]


def seed() -> None:
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        added = 0
        for entry in HELPLINES:
            exists = db.query(Helpline).filter(Helpline.phone == entry["phone"]).first()
            if exists:
                continue
            db.add(Helpline(**entry))
            added += 1
        db.commit()
        print(f"Seeded {added} new helpline(s); {len(HELPLINES) - added} already present.")
    finally:
        db.close()


if __name__ == "__main__":
    seed()
