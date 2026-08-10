import base64
import hashlib
import logging
from datetime import datetime, timedelta, timezone

from jose import jwt, ExpiredSignatureError, JWTError
import bcrypt

from app.config import get_settings

settings = get_settings()
logger = logging.getLogger("durga")


# ── Password helpers ──


def _prehash(plain: str) -> bytes:
    # FIX: bcrypt silently truncates input at 72 bytes, but passwords are
    # allowed up to 128 chars, so two different long passwords could unlock
    # the same account. SHA-256 first guarantees bcrypt always sees <=72 bytes.
    return base64.b64encode(hashlib.sha256(plain.encode("utf-8")).digest())


def hash_password(plain: str) -> str:
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(_prehash(plain), salt)
    return hashed.decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(_prehash(plain), hashed.encode("utf-8"))
    except Exception:
        return False


# ── JWT helpers ──


def create_access_token(subject: str) -> str:
    """Create a JWT with the user's UUID as the `sub` claim."""
    now = datetime.now(timezone.utc)
    expire = now + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    payload = {"sub": subject, "iat": now, "exp": expire, "typ": "access"}
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def decode_access_token(token: str) -> str | None:
    """Return the `sub` claim (user UUID string) or None if invalid/expired."""
    try:
        payload = jwt.decode(
            token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM]
        )
        return payload.get("sub")
    except ExpiredSignatureError:
        logger.info("Token expired")
        return None
    except JWTError:
        logger.warning("Token failed verification (forged or malformed)")
        return None
