import uuid
from typing import Optional

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.user import User
from app.core.security import decode_access_token

# FIX: default auto_error=True returned a bare 403 with no WWW-Authenticate
# header when the Authorization header was missing, so clients couldn't
# distinguish "never logged in" from "token rejected" (RFC 6750 wants 401).
bearer_scheme = HTTPBearer(auto_error=False)


def _unauthorized(detail: str) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=detail,
        headers={"WWW-Authenticate": "Bearer"},
    )


def _resolve_user(
    credentials: Optional[HTTPAuthorizationCredentials], db: Session
) -> Optional[User]:
    if credentials is None:
        return None

    user_id_str = decode_access_token(credentials.credentials)
    if user_id_str is None:
        return None

    try:
        user_uuid = uuid.UUID(user_id_str)
    except ValueError:
        return None

    user = db.query(User).filter(User.id == user_uuid).first()
    if user is None or not user.is_active:
        return None

    return user


def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> User:
    """Shared dependency: extract JWT from Authorization header, validate, return User."""
    if credentials is None:
        raise _unauthorized("Not authenticated")

    user = _resolve_user(credentials, db)
    if user is None:
        raise _unauthorized("Invalid or expired token")

    return user


def get_current_user_optional(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> Optional[User]:
    """Same as get_current_user but never raises - for endpoints usable logged out."""
    return _resolve_user(credentials, db)
