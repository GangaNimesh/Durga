import time
from collections import defaultdict, deque

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.user import User
from app.schemas.auth import (
    RegisterRequest,
    LoginRequest,
    TokenResponse,
    UserResponse,
)
from app.config import get_settings
from app.core.security import hash_password, verify_password, create_access_token
from app.core.deps import get_current_user

router = APIRouter()
settings = get_settings()

# FIX: on an unknown email, verify_password was never called, so the response
# returned in ~1ms instead of ~250ms - a trivially harvestable timing leak
# that lets an attacker enumerate registered emails. Always run one bcrypt
# check against a precomputed dummy hash so both paths cost the same.
_DUMMY_HASH = hash_password("not-a-real-password-000")

# In-process per-IP rate limiter: 10 attempts / 5 minutes.
# NOTE: this resets on restart and is per-worker, not shared across processes.
# Adequate for a demo; use slowapi + Redis if this ever ships.
_LOGIN_ATTEMPTS: dict[str, deque] = defaultdict(deque)
_RATE_LIMIT_WINDOW_SECONDS = 5 * 60
_RATE_LIMIT_MAX_ATTEMPTS = 10


def _check_rate_limit(client_ip: str) -> None:
    now = time.monotonic()
    attempts = _LOGIN_ATTEMPTS[client_ip]
    while attempts and now - attempts[0] > _RATE_LIMIT_WINDOW_SECONDS:
        attempts.popleft()
    if len(attempts) >= _RATE_LIMIT_MAX_ATTEMPTS:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many login attempts. Try again later.",
        )
    attempts.append(now)


@router.post(
    "/register",
    response_model=UserResponse,
    status_code=status.HTTP_201_CREATED,
)
def register(body: RegisterRequest, db: Session = Depends(get_db)):
    """Register a new user. Returns the created user profile."""
    existing = db.query(User).filter(User.email == body.email).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email already registered",
        )

    user = User(
        email=body.email,
        full_name=body.full_name,
        phone=body.phone,
        password_hash=hash_password(body.password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.post("/login", response_model=TokenResponse)
def login(body: LoginRequest, request: Request, db: Session = Depends(get_db)):
    """Authenticate with email + password. Returns a JWT access token."""
    client_ip = request.client.host if request.client else "unknown"
    _check_rate_limit(client_ip)

    user = db.query(User).filter(User.email == body.email).first()

    # Always verify against something, even on unknown email, so timing
    # doesn't reveal whether the account exists.
    password_hash = user.password_hash if user else _DUMMY_HASH
    password_ok = verify_password(body.password, password_hash)

    if not user or not password_ok:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is deactivated",
        )

    token = create_access_token(subject=str(user.id))
    return TokenResponse(
        access_token=token,
        expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
    )


@router.get("/me", response_model=UserResponse)
def get_me(current_user: User = Depends(get_current_user)):
    """Return the profile of the currently authenticated user."""
    return current_user
