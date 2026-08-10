import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text

from app.api.v1.router import v1_router
from app.config import get_settings
from app.database import Base, SessionLocal, engine
import app.models  # noqa: F401 - registers all models on Base.metadata before create_all

logger = logging.getLogger("durga")
settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    db = SessionLocal()
    try:
        db.execute(text("SELECT 1"))
        db.close()
    except Exception:
        logger.exception("Database connectivity check failed at startup")
        raise

    # FIX: fresh SQLite clones had no tables until `alembic upgrade head` was
    # run manually. create_all() makes a fresh clone work with zero setup.
    # Postgres keeps Alembic as the source of truth - never auto-create there.
    if settings.is_sqlite:
        Base.metadata.create_all(bind=engine)
    else:
        logger.info("Postgres detected - run 'alembic upgrade head' to apply migrations.")

    yield


app = FastAPI(
    title="Durga Safety API",
    description="Backend for the Durga Women Safety Application",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

# FIX: no CORS middleware anywhere meant every browser/Flutter Web request
# was blocked at the preflight (OPTIONS -> 405, no ACAO header).
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=False,  # must be False when allow_origins includes "*"
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
)

app.include_router(v1_router)


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    # FIX: unhandled errors used to return FastAPI's bare-string 500, which
    # Dio's JSON response parsing can't handle. Always return JSON.
    logger.exception("Unhandled error on %s %s", request.method, request.url.path)
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error", "path": request.url.path},
    )


@app.get("/", tags=["health"])
def root():
    return {"service": "durga-api", "docs": "/docs", "health": "/health"}


@app.get("/health", tags=["health"])
def health_check():
    # FIX: previously always reported "ok" even when the DB was unreachable.
    db = SessionLocal()
    try:
        db.execute(text("SELECT 1"))
        database = "connected"
        database_error = None
    except Exception as exc:
        database = "unreachable"
        database_error = str(exc)
    finally:
        db.close()

    return {
        "status": "ok" if database == "connected" else "degraded",
        "database": database,
        "database_error": database_error,
        "env": settings.ENV,
    }
