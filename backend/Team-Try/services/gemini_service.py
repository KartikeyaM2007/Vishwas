# services/gemini_service.py

import google.generativeai as genai
import base64
import json
import mimetypes
import re
import requests
import time
from utils.config import GEMINI_API_KEY, OPENAI_API_KEY
from utils.utils import is_safe_sql

# Configure Gemini
api_key = GEMINI_API_KEY
gemini_configured = False

if api_key:
    if not api_key.startswith("AIza"):
        print(f"WARNING: GEMINI_API_KEY format might be invalid (does not start with AIza). Received prefix: {api_key[:6]}")
    try:
        genai.configure(api_key=api_key)
        gemini_configured = True
    except Exception as e:
        print(f"ERROR configuring Gemini: {e}")

GEMINI_MODEL_NAME = "gemini-2.5-flash"
OPENAI_VISION_MODEL_NAME = "gpt-4o-mini"
model = genai.GenerativeModel(GEMINI_MODEL_NAME)
_gemini_planner_retry_after = 0.0

ASSISTANT_ACTIONS = {
    "listen",
    "get_location",
    "ask_for_proof",
    "open_camera_photo",
    "open_camera_video",
    "upload_photo",
    "upload_video",
    "validate_evidence",
    "submit_report",
    "manual_review",
    "show_my_issues",
    "end",
    "ask_clarifying_question",
    "answer_question",
}

ASSISTANT_ISSUES = {
    "pothole",
    "water_leakage",
    "garbage",
    "streetlight",
    "road_damage",
    "other",
    None,
}

def _safe_exception_message(exc: Exception) -> str:
    message = str(exc)
    if api_key:
        message = message.replace(api_key, "[REDACTED_GEMINI_KEY]")
    message = re.sub(r"key=[^&\\s'\"]+", "key=[REDACTED_GEMINI_KEY]", message)
    return message

def _strict_evidence_prompt(claimed_issue_type: str, transcript_or_description: str) -> str:
    return f"""
You are a strict civic evidence validator for Community Hero.

Claimed issue type: {claimed_issue_type}
Citizen transcript/description: {transcript_or_description}

Look at the attached image and return JSON only with exactly these keys:
{{
  "evidence_valid": true/false,
  "confidence": 0.0-1.0,
  "visible_issue": "short description of what is visible",
  "matches_claimed_issue": true/false,
  "detected_issue_type": "pothole/water_leakage/garbage/streetlight/road_damage/other/none",
  "mismatch_reason": "why it does not match",
  "recommendation": "auto_submit/manual_review/retake_proof"
}}

Strict rules:
- If no civic issue is visible, evidence_valid=false.
- If the image shows an indoor object, table, person, random item, screen, document, or non-civic scene while the claim is water leakage, pothole, garbage, streetlight, or road damage, evidence_valid=false.
- If claimed issue is water leakage but no water, pipe leak, drain overflow, wet road, or leakage evidence is visible, evidence_valid=false.
- If claimed issue is pothole or road damage but no road surface damage is visible, evidence_valid=false.
- If claimed issue is garbage but no overflowing waste, trash pile, dump, or civic sanitation issue is visible, evidence_valid=false.
- If claimed issue is streetlight but no streetlight/electrical pole/light damage is visible, evidence_valid=false.
- If confidence < 0.65, evidence_valid=false and recommendation must be manual_review or retake_proof.
- Do not invent pipeline bursts, potholes, or other civic issues from unrelated images.
- Only use recommendation=auto_submit when the media clearly supports the issue.
"""

def _normalize_validation_result(result: dict, provider: str) -> dict:
    confidence = float(result.get("confidence", 0) or 0)
    evidence_valid = (
        bool(result.get("evidence_valid"))
        and bool(result.get("matches_claimed_issue"))
        and confidence >= 0.65
    )
    result["confidence"] = confidence
    result["evidence_valid"] = evidence_valid
    result["provider"] = provider
    if not evidence_valid and result.get("recommendation") == "auto_submit":
        result["recommendation"] = "retake_proof"
    if not evidence_valid and confidence < 0.65:
        result["validation_error_code"] = "LOW_CONFIDENCE"
    return result

def _parse_validation_json(text: str) -> dict:
    text = re.sub(r"```json|```", "", text or "").strip()
    match = re.search(r'\{[\s\S]*\}', text)
    if not match:
        raise ValueError("No JSON found in evidence validation response.")
    return json.loads(match.group())

def _parse_json_object(text: str) -> dict:
    text = re.sub(r"```json|```", "", text or "").strip()
    match = re.search(r'\{[\s\S]*\}', text)
    if not match:
        raise ValueError("No JSON object found in Gemini response.")
    return json.loads(match.group())

def _planner_issue_from_text(text: str) -> str | None:
    text = re.sub(r"[^a-z0-9\s]", " ", (text or "").lower())
    text = re.sub(r"\s+", " ", text).strip()
    if any(word in text for word in ["water", "leak", "leakage", "pipe", "drain overflow"]):
        return "water_leakage"
    pothole_patterns = [
        r"\bpotholes?\b",
        r"\bpot\s+holes?\b",
        r"\broad\s+holes?\b",
        r"\bholes?\s+(?:in|on|along|across)\s+(?:the|my|this|our)?\s*(?:road|street)\b",
        r"\bholes?\b.*\b(?:road|street)\b",
        r"\b(?:road|street)\b.*\bholes?\b",
        # Common Android STT rendering of "potholes" observed on the test phone.
        r"\bforth?\s+holes?\b",
    ]
    if any(re.search(pattern, text) for pattern in pothole_patterns):
        return "pothole"
    if any(word in text for word in ["garbage", "trash", "waste", "dump"]):
        return "garbage"
    if any(word in text for word in ["streetlight", "street light", "light pole", "lamp"]):
        return "streetlight"
    if any(word in text for word in ["road damage", "broken road", "damaged road"]):
        return "road_damage"
    return None

def _issue_confirmation(issue_type: str, user_message: str) -> str:
    labels = {
        "pothole": "potholes or road-surface holes",
        "water_leakage": "a water leakage or drainage issue",
        "garbage": "a garbage or sanitation issue",
        "streetlight": "a streetlight issue",
        "road_damage": "road damage",
        "other": "a civic issue",
    }
    label = labels.get(issue_type, issue_type.replace("_", " "))
    location_hint = ""
    lower = (user_message or "").lower()
    if "front of my" in lower or "near my" in lower:
        location_hint = " near you"
    return f"I understood that you are reporting {label}{location_hint}."

def _assistant_question_response(user_message: str) -> dict | None:
    lower = (user_message or "").lower().strip()
    if not lower:
        return None

    civic_questions = [
        (
            ["what points", "how many points", "reward", "points will"],
            "Rewards are only added for authentic reports after they are verified, approved, or resolved. Failed or manual-review reports do not earn points until approved.",
        ),
        (
            ["can i upload old photo", "can i use old photo", "is an old photo"],
            "You can upload an existing photo, but gallery media is not automatically trusted. It must still match the issue and pass evidence validation.",
        ),
        (
            ["why do you need location", "why location", "need my location"],
            "Real location helps authorities find the issue, place it on the civic map, and route it to the correct team. It is required for a verified report.",
        ),
        (
            ["what happens after manual review", "manual review"],
            "A manual-review report is checked by an authorized reviewer. It is not treated as verified and earns no reward until it is approved or resolved.",
        ),
        (
            ["report without proof", "without proof", "no proof"],
            "You cannot auto-submit a verified report without proof. A report may be sent for manual review, but it will not earn points until approved or resolved.",
        ),
        (
            ["check my complaint", "complaint status", "my issues", "check complaint"],
            "Open My Issues to see your complaint, validation status, media type, and progress.",
        ),
    ]
    for phrases, answer in civic_questions:
        if any(phrase in lower for phrase in phrases):
            return {
                "assistant_reply": answer,
                "next_action": "answer_question",
                "missing_fields": [],
                "requires_user_confirmation": False,
                "safety_status": "safe_to_continue",
                "reason": "Civic-reporting question answered.",
            }

    question_like = (
        "?" in lower
        or lower.startswith(
            (
                "who ",
                "what ",
                "why ",
                "how ",
                "tell me ",
                "open ",
                "where ",
                "when ",
            )
        )
    )
    civic_terms = [
        "civic",
        "report",
        "complaint",
        "proof",
        "photo",
        "video",
        "location",
        "reward",
        "points",
        "manual review",
        "my issues",
        "pothole",
        "garbage",
        "water leak",
        "streetlight",
        "road damage",
    ]
    if question_like and not any(term in lower for term in civic_terms):
        return {
            "assistant_reply": (
                "I can help with civic issue reporting, complaint status, proof upload, "
                "location, rewards, and manual review. What civic issue would you like to report?"
            ),
            "next_action": "listen",
            "issue_type": None,
            "clean_summary": None,
            "description": None,
            "missing_fields": ["issue"],
            "requires_user_confirmation": False,
            "safety_status": "needs_more_info",
            "reason": "Out-of-scope question redirected to civic reporting.",
        }
    return None

def _normalize_assistant_turn(result: dict, known_data: dict, user_message: str) -> dict:
    issue_type = result.get("issue_type")
    if issue_type == "null":
        issue_type = None
    if issue_type not in ASSISTANT_ISSUES:
        issue_type = known_data.get("issue_type") or _planner_issue_from_text(user_message) or None

    next_action = result.get("next_action")
    if next_action not in ASSISTANT_ACTIONS:
        next_action = _assistant_turn_fallback(user_message, known_data).get("next_action")

    missing_fields = result.get("missing_fields")
    if not isinstance(missing_fields, list):
        missing_fields = []

    safety_status = result.get("safety_status")
    if safety_status not in ["safe_to_continue", "needs_more_info", "manual_review", "block_submit"]:
        safety_status = "needs_more_info"

    return {
        "assistant_reply": str(result.get("assistant_reply") or "What civic issue would you like to report?"),
        "next_action": next_action,
        "issue_type": issue_type,
        "clean_summary": result.get("clean_summary") if result.get("clean_summary") not in ["null", ""] else known_data.get("clean_summary"),
        "description": result.get("description") if result.get("description") not in ["null", ""] else known_data.get("description"),
        "missing_fields": missing_fields,
        "requires_user_confirmation": bool(result.get("requires_user_confirmation", True)),
        "safety_status": safety_status,
        "reason": str(result.get("reason") or "Selected by assistant planner."),
    }

def _assistant_turn_fallback(user_message: str, known_data: dict) -> dict:
    known_data = known_data or {}
    user_message = user_message or ""
    question_response = _assistant_question_response(user_message)
    if question_response:
        question_response.setdefault("issue_type", known_data.get("issue_type"))
        question_response.setdefault("clean_summary", known_data.get("clean_summary"))
        question_response.setdefault("description", known_data.get("description"))
        return question_response

    mentioned_issue = _planner_issue_from_text(user_message)
    issue_type = mentioned_issue or known_data.get("issue_type")
    clean_summary = known_data.get("clean_summary")
    description = known_data.get("description") or user_message.strip() or clean_summary
    lat = known_data.get("latitude")
    lng = known_data.get("longitude")
    media_present = bool(known_data.get("media_present"))
    validation_status = known_data.get("validation_status")
    validation_confidence = float(known_data.get("validation_confidence") or 0)
    missing_fields = []

    lower = user_message.lower()
    if any(phrase in lower for phrase in ["cannot take", "can't take", "no photo", "no proof"]):
        return {
            "assistant_reply": "I can submit this for manual review, but it cannot be auto-verified without proof.",
            "next_action": "manual_review",
            "issue_type": issue_type,
            "clean_summary": clean_summary,
            "description": description,
            "missing_fields": ["proof"],
            "requires_user_confirmation": True,
            "safety_status": "manual_review",
            "reason": "User said proof is unavailable.",
        }

    if not issue_type:
        return {
            "assistant_reply": "What civic issue would you like to report?",
            "next_action": "listen",
            "issue_type": None,
            "clean_summary": None,
            "description": None,
            "missing_fields": ["issue"],
            "requires_user_confirmation": False,
            "safety_status": "needs_more_info",
            "reason": "No clear civic issue has been described.",
        }

    if not clean_summary:
        clean_summary = f"Citizen reported {issue_type.replace('_', ' ')}."
    if not description:
        description = clean_summary

    if lat is None or lng is None:
        missing_fields.append("location")
        return {
            "assistant_reply": (
                f"{_issue_confirmation(issue_type, user_message)} "
                "I will capture your current location so the civic team can find it."
            ),
            "next_action": "get_location",
            "issue_type": issue_type,
            "clean_summary": clean_summary,
            "description": description,
            "missing_fields": missing_fields,
            "requires_user_confirmation": False,
            "safety_status": "safe_to_continue",
            "reason": "Issue is clear and real GPS is required next.",
        }

    if any(phrase in lower for phrase in ["already have a photo", "have a photo", "upload photo", "gallery photo"]):
        return {
            "assistant_reply": "Choose the existing photo from your gallery. It will still be checked against the reported issue.",
            "next_action": "upload_photo",
            "issue_type": issue_type,
            "clean_summary": clean_summary,
            "description": description,
            "missing_fields": ["proof"],
            "requires_user_confirmation": True,
            "safety_status": "safe_to_continue",
            "reason": "User chose an existing photo from the gallery.",
        }
    if any(phrase in lower for phrase in ["have a video", "upload video", "gallery video", "existing video"]):
        return {
            "assistant_reply": "Choose the existing video from your gallery. Video proof will be sent for manual review.",
            "next_action": "upload_video",
            "issue_type": issue_type,
            "clean_summary": clean_summary,
            "description": description,
            "missing_fields": ["proof"],
            "requires_user_confirmation": True,
            "safety_status": "safe_to_continue",
            "reason": "User chose an existing video from the gallery.",
        }
    if "take photo" in lower or "camera photo" in lower or "open camera" in lower:
        return {
            "assistant_reply": "Please take a clear photo of the civic issue.",
            "next_action": "open_camera_photo",
            "issue_type": issue_type,
            "clean_summary": clean_summary,
            "description": description,
            "missing_fields": ["proof"],
            "requires_user_confirmation": True,
            "safety_status": "safe_to_continue",
            "reason": "User chose photo proof.",
        }
    if "record video" in lower:
        return {
            "assistant_reply": "Please record a short video of the civic issue.",
            "next_action": "open_camera_video",
            "issue_type": issue_type,
            "clean_summary": clean_summary,
            "description": description,
            "missing_fields": ["proof"],
            "requires_user_confirmation": True,
            "safety_status": "safe_to_continue",
            "reason": "User chose video proof.",
        }

    if not media_present:
        return {
            "assistant_reply": f"Location captured. Take or upload a photo or video as proof of the {issue_type.replace('_', ' ')}.",
            "next_action": "ask_for_proof",
            "issue_type": issue_type,
            "clean_summary": clean_summary,
            "description": description,
            "missing_fields": ["proof"],
            "requires_user_confirmation": True,
            "safety_status": "safe_to_continue",
            "reason": "Location exists but proof is missing.",
        }

    if validation_status in [None, "", "pending"]:
        return {
            "assistant_reply": "Please wait while I verify the proof.",
            "next_action": "validate_evidence",
            "issue_type": issue_type,
            "clean_summary": clean_summary,
            "description": description,
            "missing_fields": [],
            "requires_user_confirmation": False,
            "safety_status": "safe_to_continue",
            "reason": "Proof exists and must be validated before submission.",
        }

    if validation_status == "verified" and validation_confidence >= 0.65:
        return {
            "assistant_reply": "Proof verified. I am raising your complaint now.",
            "next_action": "submit_report",
            "issue_type": issue_type,
            "clean_summary": clean_summary,
            "description": description,
            "missing_fields": [],
            "requires_user_confirmation": False,
            "safety_status": "safe_to_continue",
            "reason": "Evidence validation passed with sufficient confidence.",
        }

    return {
        "assistant_reply": "AI evidence validation is temporarily unavailable or the proof did not match. I can submit this for manual review, but it cannot be auto-verified.",
        "next_action": "manual_review",
        "issue_type": issue_type,
        "clean_summary": clean_summary,
        "description": description,
        "missing_fields": [],
        "requires_user_confirmation": True,
        "safety_status": "manual_review",
        "reason": "Validation failed, provider failed, or confidence was too low.",
    }

def plan_assistant_turn(citizen_id: str, user_message: str, current_state: str, known_data: dict) -> dict:
    global _gemini_planner_retry_after
    known_data = known_data or {}
    lower_message = (user_message or "").lower()
    deterministic_question = _assistant_question_response(user_message)
    proof_choice_phrases = [
        "already have a photo",
        "have a photo",
        "upload photo",
        "gallery photo",
        "have a video",
        "upload video",
        "gallery video",
        "existing video",
        "take photo",
        "camera photo",
        "open camera",
        "record video",
    ]
    if deterministic_question or any(
        phrase in lower_message for phrase in proof_choice_phrases
    ):
        return _assistant_turn_fallback(user_message, known_data)
    if time.monotonic() < _gemini_planner_retry_after:
        fallback = _assistant_turn_fallback(user_message, known_data)
        fallback["planner_provider"] = "rule_fallback"
        fallback["planner_error"] = "GEMINI_QUOTA_COOLDOWN"
        return fallback

    prompt = f"""
You are Community Hero, a civic reporting assistant. Your job is to guide citizens through reporting real civic issues. You must decide the next safe app action using only the provided current state and known data. You do not directly access GPS, camera, database, or files. You only return the next action JSON. The Flutter app executes actions. Safety rule: never submit reports without real location and proof validation.

Return JSON only. No markdown. No text outside JSON.

Allowed next_action values:
listen, get_location, ask_for_proof, open_camera_photo, open_camera_video, upload_photo, upload_video, validate_evidence, submit_report, manual_review, show_my_issues, end, ask_clarifying_question, answer_question

Allowed issue_type values:
pothole, water_leakage, garbage, streetlight, road_damage, other, null

Rules:
- If user has not described an issue, ask what they want to report.
- If issue is unclear, ask one clarifying question.
- If issue is clear but no location, next_action=get_location.
- If location exists but no proof, next_action=ask_for_proof.
- If user asks to take photo, next_action=open_camera_photo.
- If user asks to record video, next_action=open_camera_video.
- If user says they already have a photo or asks to upload one, next_action=upload_photo.
- If user says they have an existing video or asks to upload one, next_action=upload_video.
- If the user is unsure how to provide proof, next_action=ask_for_proof so the app can show all four proof options.
- Briefly answer civic-reporting questions about proof, location, rewards, complaint status, and manual review with next_action=answer_question.
- You are not a general chatbot. For unrelated questions, do not answer the topic, browse, call tools, or invent facts. Politely say you only help with civic reporting and use next_action=listen.
- Treat explicit issue corrections as the latest issue_type.
- If proof exists and not validated, next_action=validate_evidence.
- If validation passes and confidence >= 0.65, next_action=submit_report.
- If validation fails, provider quota fails, confidence < 0.65, or issue/image mismatch, next_action=manual_review or ask for retake.
- Never skip real GPS for auto-submit.
- Never skip proof for auto-submit.
- Never auto-submit if evidence_valid is false.
- Never auto-submit if confidence < 0.65.
- Never invent civic issues from unrelated evidence.

Current state: {current_state}
Citizen id: {citizen_id}
User message: {user_message}
Known data JSON:
{json.dumps(known_data, ensure_ascii=True)}

Return exactly this JSON shape:
{{
  "assistant_reply": "Text the assistant should speak to the user",
  "next_action": "listen|get_location|ask_for_proof|open_camera_photo|open_camera_video|upload_photo|upload_video|validate_evidence|submit_report|manual_review|show_my_issues|end|ask_clarifying_question|answer_question",
  "issue_type": "pothole|water_leakage|garbage|streetlight|road_damage|other|null",
  "clean_summary": "short cleaned summary or null",
  "description": "citizen friendly description or null",
  "missing_fields": ["location", "proof"],
  "requires_user_confirmation": true,
  "safety_status": "safe_to_continue|needs_more_info|manual_review|block_submit",
  "reason": "why this next action was selected"
}}
"""
    try:
        response = model.generate_content(prompt)
        result = _parse_json_object(response.text)
        return _normalize_assistant_turn(result, known_data, user_message)
    except Exception as e:
        safe_message = _safe_exception_message(e)
        print(f"Error in Gemini plan_assistant_turn: {type(e).__name__}: {safe_message}")
        quota_exceeded = "429" in safe_message or "quota" in safe_message.lower()
        if quota_exceeded:
            _gemini_planner_retry_after = time.monotonic() + 60
        fallback = _assistant_turn_fallback(user_message, known_data)
        fallback["planner_provider"] = "rule_fallback"
        fallback["planner_error"] = (
            "GEMINI_QUOTA_EXCEEDED"
            if quota_exceeded
            else f"GEMINI_PLANNER_{type(e).__name__.upper()}"
        )
        return fallback

def _openai_vision_validate(image_bytes: bytes, mime_type: str, prompt: str) -> dict:
    if not OPENAI_API_KEY:
        raise RuntimeError("OPENAI_API_KEY is not configured.")

    image_base64 = base64.b64encode(image_bytes).decode("ascii")
    response = requests.post(
        "https://api.openai.com/v1/chat/completions",
        headers={
            "Authorization": f"Bearer {OPENAI_API_KEY}",
            "Content-Type": "application/json",
        },
        json={
            "model": OPENAI_VISION_MODEL_NAME,
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": prompt},
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:{mime_type};base64,{image_base64}",
                                "detail": "low",
                            },
                        },
                    ],
                }
            ],
            "temperature": 0,
            "response_format": {"type": "json_object"},
        },
        timeout=45,
    )
    if response.status_code >= 400:
        raise RuntimeError(f"OpenAI Vision HTTP {response.status_code}: {response.text[:500]}")
    payload = response.json()
    text = payload["choices"][0]["message"]["content"]
    return _parse_validation_json(text)

TABLE_SCHEMA = """
Table: complaints

Columns:
id, username, issue_type, latitude, longitude, severity, complaint_desc, image_url, resolved_image_url, 
embedding, upvotes, status, submitted_at, community_confirmations, duplicate_reports, duplicate_of, 
trust_score, priority_score, ai_metadata, updated_at, urgency_score, urgency_label, department, 
admin_action_recommendation
"""

def analyze_civic_issue(image_url, issue_type, latitude, longitude, user_description=""):
    """
    Analyzes a civic issue using Google Gemini and returns a structured JSON response.
    """
    prompt = f"""
You are an AI assistant for a civic issue management platform called Community Hero.
Your task is to analyze a reported civic issue and return a STRICT JSON object.

Image URL: {image_url}
Issue Type Selected by User: {issue_type}
Latitude: {latitude}
Longitude: {longitude}
User Description: {user_description}

Based on the provided information, generate a JSON object with the following keys EXACTLY:
- "clean_summary": A clear, elaborated, and professional summary of the issue.
- "detected_category": Must be one of ["pothole", "garbage", "streetlight", "water_leak", "drainage", "road_damage", "other"]
- "urgency_score": An integer from 1 to 10 (10 being most urgent).
- "urgency_label": Must be one of ["low", "medium", "high", "critical"]
- "department": Must be one of ["Road Works", "Sanitation", "Water Department", "Electricity Department", "General Civic Team"]
- "admin_action_recommendation": A short recommendation for the admin on what to do next.
- "citizen_friendly_status_message": A reassuring message to show the citizen.
- "duplicate_check_keywords": An array of 2-3 keywords to help with duplicate detection.
- "safety_notes": Any immediate safety risks, or "None observed".

Return ONLY valid JSON. No markdown formatting blocks around it. Do not include ```json tags.
"""

    try:
        response = model.generate_content(prompt)
        text = response.text
        
        # Clean markdown if present
        text = re.sub(r"```json|```", "", text).strip()
        
        # Extract JSON safely
        match = re.search(r'\{[\s\S]*\}', text)
        if match:
            return json.loads(match.group())
        else:
            raise ValueError("No JSON found in response.")
            
    except Exception as e:
        print(f"Error in Gemini analyze_civic_issue: {e}")
        # Return a safe default fallback
        return {
            "clean_summary": f"Reported issue of type {issue_type}. AI analysis failed.",
            "detected_category": issue_type.lower() if issue_type else "other",
            "urgency_score": 5,
            "urgency_label": "medium",
            "department": "General Civic Team",
            "admin_action_recommendation": "Manual review required due to AI fallback.",
            "citizen_friendly_status_message": "We have received your report and are reviewing it.",
            "duplicate_check_keywords": [issue_type],
            "safety_notes": "Unable to assess automatically."
        }


def generate_sql_and_chart(user_query: str):
    """
    Replaces Groq. Uses Gemini to translate natural language to SQL for analytics.
    """
    prompt = f"""
You are an AI data analyst for a municipal dashboard.

{TABLE_SCHEMA}

Tasks:
1. Convert user query into PostgreSQL SQL query
2. Decide best chart type: line, bar, histogram

Rules:
- ONLY output a JSON object. No other text.
- Only SELECT queries allowed.
- Use GROUP BY if aggregation is needed.
- Use proper column names.
- ALWAYS add LIMIT 100 to the query unless a smaller limit is requested.

Return JSON EXACTLY like this:
{{
  "sql": "SELECT ... LIMIT 100;",
  "chart": "line"
}}

User Query:
{user_query}
"""
    try:
        response = model.generate_content(prompt)
        text = response.text
        
        # Clean markdown if present
        text = re.sub(r"```json|```", "", text).strip()
        
        # Extract JSON
        match = re.search(r'\{[\s\S]*\}', text)
        if match:
            result = json.loads(match.group())
            
            # Safety check
            if not is_safe_sql(result.get("sql", "")):
                raise Exception("Unsafe SQL detected!")
            
            # Ensure LIMIT 100 exists
            sql = result["sql"].strip()
            if "limit " not in sql.lower():
                if sql.endswith(";"):
                    sql = sql[:-1] + " LIMIT 100;"
                else:
                    sql += " LIMIT 100"
                result["sql"] = sql
                
            return result
        else:
            raise ValueError("No JSON found in response.")
            
    except Exception as e:
        print(f"Error in Gemini generate_sql_and_chart: {e}")
        # Return a readable error instead of crashing
        error_str = str(e)
        if "400" in error_str or "API_KEY_INVALID" in error_str or "API key not valid" in error_str:
            return {
                "error": "Invalid Gemini API Key. Please check your Google AI Studio key.",
                "details": error_str
            }
        return {
            "error": "Failed to generate analytics via Gemini.",
            "details": error_str
        }

def analyze_voice_report(transcript: str, latitude: float, longitude: float):
    """
    Analyzes a voice transcript using Google Gemini and returns a structured JSON response.
    """
    prompt = f"""
You are an AI assistant for a civic issue management platform called Community Hero.
Your task is to analyze a voice transcript from a citizen reporting a civic issue and return a STRICT JSON object.

Transcript: "{transcript}"
Latitude: {latitude}
Longitude: {longitude}

Based on the transcript, extract the details and generate a JSON object with the following keys EXACTLY:
- "clean_summary": A clear, elaborated, and professional summary of the issue.
- "detected_category": Must be one of ["pothole", "garbage", "streetlight", "water_leak", "drainage", "road_damage", "public_safety", "other"]
- "urgency_score": An integer from 1 to 10 (10 being most urgent).
- "urgency_label": Must be one of ["low", "medium", "high", "critical"]
- "department": Must be one of ["Road Works", "Sanitation", "Water Department", "Electricity Department", "Public Safety", "General Civic Team"]
- "admin_action_recommendation": A short recommendation for the admin on what to do next.
- "citizen_friendly_status_message": A reassuring message to show the citizen.
- "duplicate_check_keywords": An array of 2-3 keywords to help with duplicate detection.
- "safety_notes": Any immediate safety risks, or "None observed".

Return ONLY valid JSON. No markdown formatting blocks around it. Do not include ```json tags.
"""

    try:
        response = model.generate_content(prompt)
        text = response.text
        
        # Clean markdown if present
        text = re.sub(r"```json|```", "", text).strip()
        
        # Extract JSON safely
        match = re.search(r'\{[\s\S]*\}', text)
        if match:
            return json.loads(match.group())
        else:
            raise ValueError("No JSON found in response.")
            
    except Exception as e:
        print(f"Error in Gemini analyze_voice_report: {e}")
        # Return a safe default fallback
        return {
            "clean_summary": f"Reported issue via voice. AI analysis failed.",
            "detected_category": "other",
            "urgency_score": 5,
            "urgency_label": "medium",
            "department": "General Civic Team",
            "admin_action_recommendation": "Manual review required due to AI fallback.",
            "citizen_friendly_status_message": "We have received your voice report and are reviewing it.",
            "duplicate_check_keywords": ["voice"],
            "safety_notes": "Unable to assess automatically."
        }


def validate_civic_evidence(
    media_path: str,
    media_type: str,
    claimed_issue_type: str,
    transcript_or_description: str,
    mime_type: str | None = None,
):
    """
    Strictly validates whether uploaded evidence visibly supports the claimed civic issue.
    Video semantic validation is intentionally conservative: it requires manual review unless
    a frame extraction pipeline is added.
    """
    media_type = (media_type or "image").lower()
    claimed_issue_type = (claimed_issue_type or "other").lower()

    if media_type == "video":
        return {
            "evidence_valid": False,
            "confidence": 0.0,
            "visible_issue": "Video proof uploaded; automatic video semantic validation is not enabled.",
            "matches_claimed_issue": False,
            "detected_issue_type": "other",
            "mismatch_reason": "Video requires manual review because no frame validation pipeline is configured.",
            "recommendation": "manual_review"
        }

    mime_type = mime_type or mimetypes.guess_type(media_path)[0] or "image/jpeg"
    if mime_type not in ["image/jpeg", "image/png", "image/webp"]:
        return {
            "evidence_valid": False,
            "confidence": 0.0,
            "visible_issue": "Unsupported image MIME type.",
            "matches_claimed_issue": False,
            "detected_issue_type": "none",
            "mismatch_reason": "Unsupported proof file type. Please upload JPG, PNG, WEBP, or MP4.",
            "recommendation": "retake_proof",
            "validation_error_code": "UNSUPPORTED_IMAGE_TYPE"
        }

    prompt = _strict_evidence_prompt(claimed_issue_type, transcript_or_description)

    try:
        with open(media_path, "rb") as image_file:
            image_bytes = image_file.read()

        if not image_bytes:
            raise ValueError("Image file is empty.")

        response = model.generate_content([
            prompt,
            {
                "mime_type": mime_type,
                "data": image_bytes,
            },
        ])
        return _normalize_validation_result(
            _parse_validation_json(response.text),
            "gemini",
        )
    except Exception as e:
        safe_message = _safe_exception_message(e)
        print(f"Error in Gemini validate_civic_evidence: {type(e).__name__}: {safe_message}")
        gemini_error_code = "AI_UNAVAILABLE"
        if "API_KEY_INVALID" in safe_message or "API key not valid" in safe_message:
            gemini_error_code = "GEMINI_API_KEY_INVALID"
        elif "429" in safe_message or "quota" in safe_message.lower():
            gemini_error_code = "GEMINI_QUOTA_EXCEEDED"
        elif "No JSON" in safe_message or "JSON" in safe_message:
            gemini_error_code = "INVALID_AI_JSON"

        if OPENAI_API_KEY:
            try:
                with open(media_path, "rb") as image_file:
                    image_bytes = image_file.read()
                result = _openai_vision_validate(image_bytes, mime_type, prompt)
                normalized = _normalize_validation_result(result, "openai")
                normalized["gemini_error_code"] = gemini_error_code
                return normalized
            except Exception as openai_error:
                safe_openai_message = _safe_exception_message(openai_error)
                if OPENAI_API_KEY:
                    safe_openai_message = safe_openai_message.replace(OPENAI_API_KEY, "[REDACTED_OPENAI_KEY]")
                print(f"Error in OpenAI validate_civic_evidence: {type(openai_error).__name__}: {safe_openai_message}")
                return {
                    "evidence_valid": False,
                    "confidence": 0.0,
                    "visible_issue": "AI evidence validation is temporarily unavailable.",
                    "matches_claimed_issue": False,
                    "detected_issue_type": "none",
                    "mismatch_reason": f"Gemini failed ({gemini_error_code}); OpenAI fallback failed: {safe_openai_message}",
                    "recommendation": "manual_review",
                    "validation_error_code": "AI_UNAVAILABLE",
                    "provider": "fail_closed",
                    "gemini_error_code": gemini_error_code,
                }

        return {
            "evidence_valid": False,
            "confidence": 0.0,
            "visible_issue": "AI evidence validation is temporarily unavailable.",
            "matches_claimed_issue": False,
            "detected_issue_type": "none",
            "mismatch_reason": f"Evidence validation failed: {safe_message}",
            "recommendation": "manual_review",
            "validation_error_code": gemini_error_code,
            "provider": "fail_closed"
        }
