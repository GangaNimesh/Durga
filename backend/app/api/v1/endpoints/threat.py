import re
from typing import Optional

from fastapi import APIRouter, Depends
from app.core.deps import get_current_user_optional
from app.models.user import User
from app.schemas.features import ThreatRequest, ThreatResponse

router = APIRouter()

# NOTE: this is rule-based keyword triage, not AI. There is no model, no
# training, no learning involved - it is a weighted keyword scorer. Do not
# let product copy ("AI-Based Threat Detection") rest on this file.

HIGH_RISK_WEIGHT = 40
MEDIUM_RISK_WEIGHT = 15

HIGH_RISK_KEYWORDS = {"danger", "attack", "follow", "threat", "harass", "weapon", "knife", "gun", "kill"}
MEDIUM_RISK_KEYWORDS = {"help", "scared", "alone", "unsafe", "lost", "stranger"}

_WORD_RE = re.compile(r"[a-z']+")


@router.post("/analyze", response_model=ThreatResponse)
def analyze_threat(
    request: ThreatRequest,
    current_user: Optional[User] = Depends(get_current_user_optional),
):
    """Score free text for safety-relevant keywords.

    Rule-based keyword triage, not AI/ML. Word-boundary matched so "helpful"
    or "shelter" don't false-positive on "help"/"her".
    """
    words = set(_WORD_RE.findall(request.text.lower()))

    matched_high = sorted(words & HIGH_RISK_KEYWORDS)
    matched_medium = sorted(words & MEDIUM_RISK_KEYWORDS)
    matched_keywords = matched_high + matched_medium

    score = min(100, len(matched_high) * HIGH_RISK_WEIGHT + len(matched_medium) * MEDIUM_RISK_WEIGHT)

    if score >= HIGH_RISK_WEIGHT:
        risk_level, color = "High Risk", "red"
    elif score >= MEDIUM_RISK_WEIGHT:
        risk_level, color = "Medium Risk", "orange"
    else:
        risk_level, color = "Low Risk", "green"

    return ThreatResponse(
        risk_level=risk_level,
        color=color,
        score=score,
        matched_keywords=matched_keywords,
    )
