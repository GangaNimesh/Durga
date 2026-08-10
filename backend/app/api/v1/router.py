from fastapi import APIRouter
from app.api.v1.endpoints import auth, contacts, sos, journey, evidence, threat, helplines

v1_router = APIRouter(prefix="/api/v1")
v1_router.include_router(auth.router, prefix="/auth", tags=["auth"])
v1_router.include_router(contacts.router, prefix="/contacts", tags=["contacts"])
v1_router.include_router(sos.router, prefix="/sos", tags=["sos"])
v1_router.include_router(journey.router, prefix="/journey", tags=["journey"])
v1_router.include_router(evidence.router, prefix="/evidence", tags=["evidence"])
v1_router.include_router(threat.router, prefix="/threat", tags=["threat"])
v1_router.include_router(helplines.router, prefix="/helplines", tags=["helplines"])
