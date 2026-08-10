# NOTE: prefer importing get_db from app.database and get_current_user /
# get_current_user_optional from app.core.deps directly in new code. This
# module exists only for backwards-compatible import paths.
from app.database import get_db
from app.core.deps import get_current_user, get_current_user_optional

__all__ = ["get_db", "get_current_user", "get_current_user_optional"]
