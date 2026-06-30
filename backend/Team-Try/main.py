from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from services.cloudinary import upload_image, upload_media
from services.gemini_service import analyze_civic_issue, generate_sql_and_chart, analyze_voice_report, validate_civic_evidence, plan_assistant_turn, GEMINI_MODEL_NAME
from services.supabase import insert_complaint
from model.classifier import predict_and_embed
from datetime import datetime
from services.supabase import run_sql
from model.models import QueryRequest
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi import Request
from services.supabase import supabase
from utils.utils import is_safe_sql
from utils.config import LOADED_ENV_PATH, SUPABASE_URL, SUPABASE_KEY, GEMINI_API_KEY, OPENAI_API_KEY
from model.classifier import process_image, FALLBACK_MODE as classifier_fallback
from model.classifier2 import validate_and_extract_features, FALLBACK_MODE as classifier2_fallback
import os
import traceback
import json
import re
from html import escape
from typing import Optional, Any

app = FastAPI()

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    print(f"Global Exception: {exc}")
    print(traceback.format_exc())
    return JSONResponse(
        status_code=500,
        content={"error": "Internal Server Error", "details": str(exc)},
    )


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 🔥 allow all (for development)
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.post("/upload_details")
async def upload_details(
    username: str = Form(...),
    issue_type: str = Form(...),
    latitude: float = Form(...),
    longitude: float = Form(...),
    image: UploadFile = File(...)
):

    # Validation
    if not username or not username.strip():
        raise HTTPException(status_code=400, detail="Username cannot be empty")
    _require_real_coordinates(latitude, longitude)
    if not image or not image.filename:
        raise HTTPException(status_code=400, detail="Missing image")

    # 1️⃣ Save image locally (needed for model)
    file_location = f"temp_{image.filename}"
    with open(file_location, "wb") as f:
        f.write(await image.read())

    # 2️⃣ ML Model Prediction ✅
    result = predict_and_embed(file_location)

    # ❌ If not pothole → reject early
    if result["class"] != "pothole":
        raise HTTPException(status_code=400, detail="No valid issue detected in the image")

    # 3️⃣ Upload image to Cloudinary
    image_url = upload_image(open(file_location, "rb"))

    # 4️⃣ LLM → Comprehensive Gemini Analysis
    llm_result = analyze_civic_issue(
        image_url,
        issue_type,
        latitude,
        longitude
    )

    description = llm_result.get("clean_summary", "")

    # 5️⃣ Store in DB
    data = {
        "username": username,
        "issue_type": issue_type,
        "latitude": latitude,
        "longitude": longitude,
        "severity": result["severity"],  # ✅ from model
        "complaint_desc": description,
        "image_url": image_url,
        "embedding": result["embedding"],  # ✅ already computed
        "upvotes": 1,
        "status": "pending",
        "submitted_at": datetime.utcnow().isoformat(),
        # New Community Hero AI Fields
        "urgency_score": llm_result.get("urgency_score", 5),
        "urgency_label": llm_result.get("urgency_label", "medium"),
        "department": llm_result.get("department", "General Civic Team"),
        "admin_action_recommendation": llm_result.get("admin_action_recommendation", ""),
        "ai_metadata": llm_result,
        "community_confirmations": 0,
        "duplicate_reports": 0,
        "priority_score": result["severity"] + llm_result.get("urgency_score", 5)
    }

    insert_complaint(data)

    # 6️⃣ Final response
    from model.classifier import FALLBACK_MODE as classifier_fallback
    from model.classifier2 import FALLBACK_MODE as classifier2_fallback

    return {
        "is_true_image": True,
        "complaint_description": description,
        "severity": result["severity"],
        "ai_analysis": llm_result,
        "validation_mode": "fallback" if (classifier_fallback or classifier2_fallback) else "real"
    }


# -------------------------
# UPDATE DESCRIPTION API
# -------------------------
from fastapi import Body
from services.supabase import supabase

@app.put("/upload-complaint")
async def update_description(
    complaint_id: int = Body(...),
    new_description: str = Body(...)
):
    
    response = supabase.table("complaints")\
        .update({"complaint_desc": new_description})\
        .eq("id", complaint_id)\
        .execute()

    return {
        "message": "Description updated successfully",
        "updated_id": complaint_id
    }


@app.get("/")
async def hello():
    return {"message": "Hello Hi This is My Backend"}


@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "gemini_configured": bool(GEMINI_API_KEY),
        "supabase_configured": bool(SUPABASE_URL and SUPABASE_KEY),
        "cloudinary_configured": True,  # Already configured in cloudinary.py
        "model_mode": "fallback" if (classifier_fallback or classifier2_fallback) else "real",
        "timestamp": datetime.utcnow().isoformat()
    }

@app.get("/debug-config")
async def debug_config():
    return {
        "loaded_env_path": LOADED_ENV_PATH,
        "supabase_url": SUPABASE_URL.split("://")[-1].split("/")[0] if SUPABASE_URL else None,
        "supabase_key_present": bool(SUPABASE_KEY),
        "gemini_api_key_present": bool(GEMINI_API_KEY),
        "gemini_api_key_prefix": GEMINI_API_KEY[:6] if GEMINI_API_KEY else None,
        "openai_api_key_present": bool(OPENAI_API_KEY),
        "openai_api_key_prefix": OPENAI_API_KEY[:5] if OPENAI_API_KEY else None,
        "cloudinary_configured": True,
        "cwd": os.getcwd()
    }


@app.get("/complaints")
async def get_all_complaints():
    try:
        response = supabase.table("complaints")\
            .select("""
                id,
                username,
                issue_type,
                latitude,
                longitude,
                severity,
                complaint_desc,
                image_url,
                media_url,
                media_type,
                upvotes,
                status,
                submitted_at,
                community_confirmations,
                duplicate_reports,
                priority_score,
                department,
                urgency_score,
                urgency_label,
                validation_status,
                validation_confidence,
                validation_provider,
                reward_eligible,
                auto_submitted,
                citizen_id,
                ai_metadata
            """)\
            .order("submitted_at", desc=True)\
            .execute()

        public_rows = []
        for row in response.data or []:
            if _is_invalid_public_location(row):
                continue
            item = _complaint_summary(row)
            item["comments_count"] = _try_table_count("complaint_comments", "complaint_id", item["id"])
            public_rows.append(item)

        return {
            "count": len(public_rows),
            "data": public_rows
        }
    except Exception as e:
        error_msg = str(e)
        if "relation \"public.complaints\" does not exist" in error_msg or "PGRST205" in error_msg:
            raise HTTPException(
                status_code=503,
                detail="Supabase connected, but complaints table missing. Run docs/supabase_schema.sql in Supabase SQL Editor."
            )
        raise HTTPException(
            status_code=500,
            detail=f"Failed to fetch complaints from Supabase. {error_msg}"
        )

def _badge_for_points(points: int) -> str:
    if points >= 250:
        return "City Guardian"
    if points >= 100:
        return "Community Hero"
    if points >= 50:
        return "Civic Helper"
    if points >= 10:
        return "Starter Reporter"
    return "New Reporter"

def _is_verified_complaint(complaint: dict) -> bool:
    metadata = complaint.get("ai_metadata") or {}
    validation = metadata.get("validation") or {}
    validation_status = (
        complaint.get("validation_status")
        or metadata.get("validation_status")
        or validation.get("validation_status")
        or ""
    )
    return bool(validation.get("evidence_valid")) or validation_status in ["verified", "admin_approved"]

@app.get("/mobile/leaderboard")
@app.get("/leaderboard")
async def mobile_leaderboard():
    try:
        response = supabase.table("complaints").select("*").execute()
        stats = {}
        for complaint in response.data or []:
            username = complaint.get("username") or "unknown"
            entry = stats.setdefault(username, {
                "username": username,
                "points": 0,
                "authentic_reports": 0,
                "resolved_reports": 0,
                "manual_review_reports": 0,
                "rejected_reports": 0,
            })

            status = (complaint.get("status") or "").lower()
            metadata = complaint.get("ai_metadata") or {}
            media_type = complaint.get("media_type") or metadata.get("media_type")
            confirmations = int(complaint.get("community_confirmations") or 0)
            verified = _is_verified_complaint(complaint)
            validation_status = complaint.get("validation_status") or metadata.get("validation_status")
            reward_eligible = complaint.get("reward_eligible")
            if reward_eligible is None:
                reward_eligible = metadata.get("reward_eligible")
            manual_review_approved = validation_status == "admin_approved"

            if status == "manual_review" or validation_status == "manual_review":
                entry["manual_review_reports"] += 1

            if status in ["rejected", "fake", "spam", "duplicate"]:
                entry["rejected_reports"] += 1
                entry["points"] -= 10
                continue

            if manual_review_approved:
                entry["authentic_reports"] += 1
                entry["points"] += 10
            elif verified and reward_eligible is not False:
                entry["authentic_reports"] += 1
                entry["points"] += 10

            if status in ["resolved", "solved"] and (verified or manual_review_approved):
                entry["resolved_reports"] += 1
                entry["points"] += 25
                if media_type == "video":
                    entry["points"] += 5

            if confirmations >= 3 and verified:
                entry["points"] += 5

        ranked = sorted(stats.values(), key=lambda item: item["points"], reverse=True)
        for index, item in enumerate(ranked, start=1):
            item["rank"] = index
            item["badge"] = _badge_for_points(item["points"])
        return ranked
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to build leaderboard: {str(e)}")


@app.post("/analyze")
@app.post("/gemini-analyze")
async def analyze(request: QueryRequest):

    try:
        # 1. LLM via Gemini
        result = generate_sql_and_chart(request.query)
        if "error" in result:
            raise HTTPException(
                status_code=400,
                detail=f"Gemini Analysis Failed: {result['error']} - {result.get('details', '')}"
            )
            
        sql = result["sql"]
        chart = result["chart"]

        # 2. DB
        data = run_sql(sql)

        return {
            "success": True,
            "query": request.query,
            "sql": sql,
            "chart": chart,
            "data": data
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# -------------------------
# COMMUNITY HERO ENDPOINTS
# -------------------------

class AdminNoteRequest(BaseModel):
    admin_id: str = "admin"
    note: str = ""
    manual_exception: bool = False

class AdminRejectRequest(BaseModel):
    admin_id: str = "admin"
    reason: str

class AdminAssignRequest(BaseModel):
    admin_id: str = "admin"
    department: str

class AdminStatusRequest(BaseModel):
    admin_id: str = "admin"
    status: str
    note: str = ""

class CommentRequest(BaseModel):
    user_id: str = "guest"
    username: str = "Guest Citizen"
    body: str
    user_role: str = "citizen"
    is_verified_user: bool = False

class CommentUpdateRequest(BaseModel):
    user_id: str = "guest"
    body: str

def _now_iso() -> str:
    return datetime.utcnow().isoformat()

def _metadata_for_complaint(complaint: dict) -> dict:
    metadata = complaint.get("ai_metadata") or {}
    if not isinstance(metadata, dict):
        metadata = {}
    return metadata

def _validation_value(complaint: dict, key: str, default=None):
    metadata = _metadata_for_complaint(complaint)
    validation = metadata.get("validation") or {}
    return complaint.get(key) or metadata.get(key) or validation.get(key) or default

def _sanitize_comment_body(body: str) -> str:
    cleaned = re.sub(r"<[^>]*>", "", body or "").strip()
    cleaned = escape(cleaned, quote=False)
    if not cleaned:
        raise HTTPException(status_code=400, detail="Comment cannot be empty")
    if len(cleaned) > 1000:
        raise HTTPException(status_code=400, detail="Comment cannot exceed 1000 characters")
    return cleaned

def _humanize(value: Any) -> str:
    text = str(value or "").replace("_", " ").strip()
    return text.title() if text else "Unknown"

def _is_invalid_public_location(complaint: dict) -> bool:
    try:
        return abs(float(complaint.get("latitude") or 0)) < 0.000001 and abs(float(complaint.get("longitude") or 0)) < 0.000001
    except Exception:
        return True

def _is_review_candidate(complaint: dict) -> bool:
    status = (complaint.get("status") or "").lower()
    validation_status = str(_validation_value(complaint, "validation_status", "") or "").lower()
    provider = str(_validation_value(complaint, "validation_provider", "") or "").lower()
    media_type = str(complaint.get("media_type") or _validation_value(complaint, "media_type", "") or "").lower()
    try:
        confidence = float(_validation_value(complaint, "validation_confidence", 1) or 0)
    except Exception:
        confidence = 0
    semantic_video_verified = (
        media_type != "video"
        or validation_status in ["verified", "admin_approved"]
        or status in ["approved", "verified", "resolved"]
    )
    return (
        status == "manual_review"
        or validation_status == "manual_review"
        or provider == "fail_closed"
        or confidence < 0.65
        or not semantic_video_verified
    )

def _complaint_summary(complaint: dict) -> dict:
    metadata = _metadata_for_complaint(complaint)
    validation = metadata.get("validation") or {}
    item = dict(complaint)
    item["validation_status"] = _validation_value(complaint, "validation_status", validation.get("validation_status"))
    item["validation_provider"] = _validation_value(complaint, "validation_provider", validation.get("provider"))
    item["validation_confidence"] = _validation_value(complaint, "validation_confidence", validation.get("confidence"))
    item["validation_reason"] = (
        validation.get("mismatch_reason")
        or validation.get("visible_issue")
        or metadata.get("reason")
        or metadata.get("admin_note")
        or metadata.get("rejection_reason")
    )
    item["reward_eligible"] = complaint.get("reward_eligible", metadata.get("reward_eligible", False))
    item["auto_submitted"] = complaint.get("auto_submitted", metadata.get("auto_submitted", False))
    item["comments_count"] = 0
    return item

def _get_complaint_or_404(complaint_id: int) -> dict:
    res = supabase.table("complaints").select("*").eq("id", complaint_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Complaint not found")
    return res.data[0]

def _try_table_count(table: str, column: str, value: Any) -> int:
    try:
        res = supabase.table(table).select("id").eq(column, value).execute()
        return len(res.data or [])
    except Exception:
        return 0

def _insert_audit_log(complaint_id: int, actor_id: str, action: str, old_status: str, new_status: str, note: str = ""):
    try:
        supabase.table("complaint_audit_logs").insert({
            "complaint_id": complaint_id,
            "actor_id": actor_id or "admin",
            "actor_role": "admin",
            "action": action,
            "old_status": old_status,
            "new_status": new_status,
            "note": note or "",
            "created_at": _now_iso(),
        }).execute()
    except Exception as e:
        print(f"[audit] skipped action={action} complaint_id={complaint_id} reason={e}")

def _complaint_update_with_fallback(complaint_id: int, payload: dict) -> dict:
    clean = {k: v for k, v in payload.items() if v is not None}
    while True:
        try:
            res = supabase.table("complaints").update(clean).eq("id", complaint_id).execute()
            return res.data[0] if res.data else _get_complaint_or_404(complaint_id)
        except Exception as e:
            msg = str(e)
            missing = re.search(r"column complaints\.([a-zA-Z0-9_]+) does not exist", msg)
            if missing and missing.group(1) in clean and len(clean) > 1:
                removed = missing.group(1)
                clean.pop(removed, None)
                print(f"[complaints:update] retrying without missing column={removed}")
                continue
            raise

def _admin_update_complaint(
    complaint_id: int,
    admin_id: str,
    action: str,
    new_status: str,
    validation_status: Optional[str] = None,
    note: str = "",
    extra_metadata: Optional[dict] = None,
    update_fields: Optional[dict] = None,
) -> dict:
    complaint = _get_complaint_or_404(complaint_id)
    old_status = complaint.get("status") or ""
    metadata = _metadata_for_complaint(complaint)
    metadata.update(extra_metadata or {})
    if validation_status:
        metadata["validation_status"] = validation_status
    if note:
        metadata["admin_note"] = note
    is_duplicate = int(complaint.get("duplicate_reports") or 0) > 0 or (complaint.get("status") or "").lower() == "duplicate"
    existing_validation_status = _validation_value(complaint, "validation_status", "")
    effective_validation_status = validation_status or existing_validation_status
    existing_reward = complaint.get("reward_eligible", metadata.get("reward_eligible", False))
    reward_eligible = bool(existing_reward) or (effective_validation_status == "admin_approved" and not is_duplicate)
    if new_status in ["rejected", "needs_more_proof", "manual_review"]:
        reward_eligible = False
    payload = {
        "status": new_status,
        "ai_metadata": metadata,
        "updated_at": _now_iso(),
        "validation_status": validation_status,
        "reward_eligible": reward_eligible,
    }
    if update_fields:
        payload.update(update_fields)
    updated = _complaint_update_with_fallback(complaint_id, payload)
    _insert_audit_log(complaint_id, admin_id, action, old_status, new_status, note)
    return updated

@app.get("/admin/review-queue")
async def get_review_queue():
    try:
        res = supabase.table("complaints").select("*").order("submitted_at", desc=True).execute()
        items = [_complaint_summary(item) for item in (res.data or []) if _is_review_candidate(item)]
        for item in items:
            item["comments_count"] = _try_table_count("complaint_comments", "complaint_id", item["id"])
        return {"count": len(items), "data": items}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to load review queue: {str(e)}")

@app.patch("/admin/complaints/{complaint_id}/approve")
async def approve_complaint(complaint_id: int, request: AdminNoteRequest):
    complaint = _get_complaint_or_404(complaint_id)
    media_url = complaint.get("media_url") or complaint.get("image_url")
    if not media_url and not request.manual_exception:
        raise HTTPException(status_code=400, detail="Cannot approve without proof media unless manual_exception=true")
    updated = _admin_update_complaint(
        complaint_id,
        request.admin_id,
        "approved",
        "approved",
        validation_status="admin_approved",
        note=request.note or "Admin approved report.",
        extra_metadata={"reward_eligible": True, "admin_approved_at": _now_iso()},
    )
    return {"success": True, "data": updated}

@app.patch("/admin/complaints/{complaint_id}/reject")
async def reject_complaint(complaint_id: int, request: AdminRejectRequest):
    reason = (request.reason or "").strip()
    if not reason:
        raise HTTPException(status_code=400, detail="Rejection reason is required")
    updated = _admin_update_complaint(
        complaint_id,
        request.admin_id,
        "rejected",
        "rejected",
        validation_status="rejected",
        note=reason,
        extra_metadata={"reward_eligible": False, "rejection_reason": reason},
    )
    return {"success": True, "data": updated}

@app.patch("/admin/complaints/{complaint_id}/request-more-proof")
async def request_more_proof(complaint_id: int, request: AdminNoteRequest):
    updated = _admin_update_complaint(
        complaint_id,
        request.admin_id,
        "needs_more_proof",
        "needs_more_proof",
        validation_status="needs_more_proof",
        note=request.note or "Please upload clearer proof of the issue.",
        extra_metadata={"reward_eligible": False},
    )
    return {"success": True, "data": updated}

@app.patch("/admin/complaints/{complaint_id}/assign")
async def assign_complaint(complaint_id: int, request: AdminAssignRequest):
    department = (request.department or "").strip()
    if not department:
        raise HTTPException(status_code=400, detail="Department is required")
    updated = _admin_update_complaint(
        complaint_id,
        request.admin_id,
        "assigned",
        _get_complaint_or_404(complaint_id).get("status") or "pending",
        note=f"Assigned to {department}.",
        extra_metadata={"assigned_department": department},
        update_fields={"department": department},
    )
    return {"success": True, "data": updated}

@app.patch("/admin/complaints/{complaint_id}/status")
async def admin_update_status(complaint_id: int, request: AdminStatusRequest):
    status = (request.status or "").strip().lower()
    if status not in ["in_progress", "resolved"]:
        raise HTTPException(status_code=400, detail="status must be in_progress or resolved")
    update_fields = {}
    if status == "resolved":
        update_fields["resolved_at"] = _now_iso()
    updated = _admin_update_complaint(
        complaint_id,
        request.admin_id,
        status,
        status,
        note=request.note or _humanize(status),
        update_fields=update_fields,
    )
    return {"success": True, "data": updated}

@app.get("/complaints/{complaint_id}/audit")
async def get_complaint_audit(complaint_id: int):
    _get_complaint_or_404(complaint_id)
    try:
        res = supabase.table("complaint_audit_logs").select("*").eq("complaint_id", complaint_id).order("created_at", desc=False).execute()
        return {"count": len(res.data or []), "data": res.data or []}
    except Exception:
        return {"count": 0, "data": []}

@app.get("/complaints/{complaint_id}/comments")
async def get_complaint_comments(complaint_id: int, sort: str = "newest"):
    _get_complaint_or_404(complaint_id)
    try:
        res = supabase.table("complaint_comments").select("*").eq("complaint_id", complaint_id).order("created_at", desc=(sort != "oldest")).execute()
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Comments table unavailable. Run docs/admin_review_comments_schema.sql. {str(e)}")
    rows = res.data or []
    if sort == "top":
        rows.sort(key=lambda item: ((item.get("upvotes") or 0) - (item.get("downvotes") or 0), item.get("created_at") or ""), reverse=True)
    elif sort == "verified":
        rows.sort(key=lambda item: (bool(item.get("is_verified_user")), item.get("created_at") or ""), reverse=True)
    by_parent = {}
    for row in rows:
        row = dict(row)
        if row.get("is_deleted"):
            row["body"] = "[deleted]"
        row["replies"] = []
        by_parent.setdefault(row.get("parent_comment_id"), []).append(row)
    lookup = {row["id"]: row for group in by_parent.values() for row in group}
    for row in rows:
        parent_id = row.get("parent_comment_id")
        if parent_id and parent_id in lookup:
            lookup[parent_id].setdefault("replies", []).append(lookup[row["id"]])
    top_level = by_parent.get(None, [])
    return {"count": len(rows), "data": top_level}

@app.post("/complaints/{complaint_id}/comments")
async def add_complaint_comment(complaint_id: int, request: CommentRequest):
    _get_complaint_or_404(complaint_id)
    body = _sanitize_comment_body(request.body)
    try:
        res = supabase.table("complaint_comments").insert({
            "complaint_id": complaint_id,
            "parent_comment_id": None,
            "user_id": request.user_id or "guest",
            "username": request.username or "Guest Citizen",
            "user_role": request.user_role or "citizen",
            "body": body,
            "is_verified_user": bool(request.is_verified_user),
            "created_at": _now_iso(),
            "updated_at": _now_iso(),
        }).execute()
        return {"success": True, "data": res.data[0] if res.data else None}
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Failed to add comment. Run docs/admin_review_comments_schema.sql if needed. {str(e)}")

@app.post("/complaints/{complaint_id}/comments/{comment_id}/reply")
async def reply_to_comment(complaint_id: int, comment_id: int, request: CommentRequest):
    _get_complaint_or_404(complaint_id)
    parent = supabase.table("complaint_comments").select("id").eq("id", comment_id).eq("complaint_id", complaint_id).execute()
    if not parent.data:
        raise HTTPException(status_code=404, detail="Parent comment not found")
    body = _sanitize_comment_body(request.body)
    res = supabase.table("complaint_comments").insert({
        "complaint_id": complaint_id,
        "parent_comment_id": comment_id,
        "user_id": request.user_id or "guest",
        "username": request.username or "Guest Citizen",
        "user_role": request.user_role or "citizen",
        "body": body,
        "is_verified_user": bool(request.is_verified_user),
        "created_at": _now_iso(),
        "updated_at": _now_iso(),
    }).execute()
    return {"success": True, "data": res.data[0] if res.data else None}

@app.patch("/comments/{comment_id}")
async def update_comment(comment_id: int, request: CommentUpdateRequest):
    body = _sanitize_comment_body(request.body)
    res = supabase.table("complaint_comments").update({
        "body": body,
        "updated_at": _now_iso(),
    }).eq("id", comment_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Comment not found")
    return {"success": True, "data": res.data[0]}

@app.delete("/comments/{comment_id}")
async def delete_comment(comment_id: int):
    res = supabase.table("complaint_comments").update({
        "is_deleted": True,
        "body": "",
        "updated_at": _now_iso(),
    }).eq("id", comment_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Comment not found")
    return {"success": True, "data": res.data[0]}

@app.post("/comments/{comment_id}/upvote")
async def upvote_comment(comment_id: int):
    res = supabase.table("complaint_comments").select("upvotes").eq("id", comment_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Comment not found")
    new_value = int(res.data[0].get("upvotes") or 0) + 1
    updated = supabase.table("complaint_comments").update({"upvotes": new_value, "updated_at": _now_iso()}).eq("id", comment_id).execute()
    return {"success": True, "data": updated.data[0] if updated.data else None}

@app.post("/comments/{comment_id}/downvote")
async def downvote_comment(comment_id: int):
    res = supabase.table("complaint_comments").select("downvotes").eq("id", comment_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Comment not found")
    new_value = int(res.data[0].get("downvotes") or 0) + 1
    updated = supabase.table("complaint_comments").update({"downvotes": new_value, "updated_at": _now_iso()}).eq("id", comment_id).execute()
    return {"success": True, "data": updated.data[0] if updated.data else None}

@app.post("/complaints/{complaint_id}/confirm")
async def confirm_complaint(complaint_id: int):
    try:
        # Fetch current
        res = supabase.table("complaints").select("community_confirmations, severity, urgency_score").eq("id", complaint_id).execute()
        if not res.data:
            raise HTTPException(status_code=404, detail="Complaint not found")
            
        current = res.data[0]
        new_confirmations = (current.get("community_confirmations") or 0) + 1
        
        # Simple Priority Formula: Severity + Urgency + (Confirmations * 0.5)
        new_priority = float(current.get("severity") or 0) + float(current.get("urgency_score") or 0) + (new_confirmations * 0.5)
        
        supabase.table("complaints").update({
            "community_confirmations": new_confirmations,
            "priority_score": new_priority,
            "updated_at": datetime.utcnow().isoformat()
        }).eq("id", complaint_id).execute()
        
        return {"success": True, "community_confirmations": new_confirmations, "priority_score": new_priority}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {str(e)}")


@app.post("/complaints/{complaint_id}/duplicate")
async def mark_duplicate(complaint_id: int):
    try:
        res = supabase.table("complaints").select("duplicate_reports").eq("id", complaint_id).execute()
        if not res.data:
            raise HTTPException(status_code=404, detail="Complaint not found")
            
        new_duplicates = (res.data[0].get("duplicate_reports") or 0) + 1
        
        supabase.table("complaints").update({
            "duplicate_reports": new_duplicates,
            "updated_at": datetime.utcnow().isoformat()
        }).eq("id", complaint_id).execute()
        
        return {"success": True, "duplicate_reports": new_duplicates}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {str(e)}")


@app.get("/complaints/{complaint_id}")
async def get_complaint(complaint_id: int):
    try:
        res = supabase.table("complaints").select("*").eq("id", complaint_id).execute()
        if not res.data:
            raise HTTPException(status_code=404, detail="Complaint not found")
        complaint = _complaint_summary(res.data[0])
        complaint["comments_count"] = _try_table_count("complaint_comments", "complaint_id", complaint_id)
        try:
            audit = supabase.table("complaint_audit_logs").select("*").eq("complaint_id", complaint_id).order("created_at", desc=False).execute()
            complaint["audit_logs"] = audit.data or []
        except Exception:
            complaint["audit_logs"] = []
        return {"success": True, "data": complaint}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {str(e)}")

# -------------------------
# ✅ Update Complaint (RESOLVED IMAGE VALIDATION)
# -------------------------


@app.put("/update-complaint")
async def update_complaint(
    complaint_id: int = Form(...),
    status: str = Form(...),
    resolved_image: UploadFile = File(...)
):
    try:
        # 1️⃣ Save
        file_location = f"resolved_{resolved_image.filename}"
        with open(file_location, "wb") as f:
            f.write(await resolved_image.read())

        # 2️⃣ ML validation
        result = validate_and_extract_features(file_location)

        # ❌ If still bad road → reject
        if result["is_clear"] is False:
            return {
                "success": False,
                "message": "Road is still damaged ❌",
                "confidence": result["confidence"]
            }

        # 3️⃣ Upload
        image_url = upload_image(open(file_location, "rb"))

        # 4️⃣ Update DB
        supabase.table("complaints")\
            .update({
                "resolved_image_url": image_url,
                "status": status
            })\
            .eq("id", complaint_id)\
            .execute()

        return {
            "success": True,
            "message": "Resolved successfully ✅",
            "image_url": image_url
        }

    except Exception as e:
        return {"success": False, "error": str(e)}

# -------------------------
# VAPI VOICE REPORTING API
# -------------------------

class VoiceReportRequest(BaseModel):
    transcript: str
    latitude: float = 0.0
    longitude: float = 0.0
    username: str = "voice_user"

class MobileVoicePrepareRequest(BaseModel):
    transcript: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    username: str = "mobile_user"

class MobileAssistantTurnRequest(BaseModel):
    citizen_id: str = "mobile_user"
    user_message: str = ""
    current_state: str = "idle"
    known_data: dict[str, Any] = {}

def _normalize_mobile_issue_type(issue_type: str) -> str:
    value = (issue_type or "other").strip().lower()
    mapping = {
        "road": "pothole",
        "roads": "pothole",
        "potholes": "pothole",
        "water": "water_leakage",
        "water_leak": "water_leakage",
        "water leakage": "water_leakage",
        "drain": "water_leakage",
        "drainage": "water_leakage",
        "electricity": "streetlight",
        "streetlight_damage": "streetlight",
        "waste": "garbage",
        "trash": "garbage",
    }
    return mapping.get(value, value)

def _safe_json_dict(raw: str, default=None):
    if default is None:
        default = {}
    try:
        return json.loads(raw) if raw else default
    except Exception:
        return default

def _gemini_key_prefix() -> Optional[str]:
    return GEMINI_API_KEY[:5] if GEMINI_API_KEY else None

def _openai_key_prefix() -> Optional[str]:
    return OPENAI_API_KEY[:5] if OPENAI_API_KEY else None

def _coordinates_valid(latitude: Optional[float], longitude: Optional[float]) -> tuple[bool, str]:
    if latitude is None or longitude is None:
        return False, "Missing latitude or longitude"
    if latitude < -90 or latitude > 90 or longitude < -180 or longitude > 180:
        return False, "Invalid latitude or longitude"
    if abs(latitude) < 0.000001 and abs(longitude) < 0.000001:
        return False, "GPS coordinates are 0,0 and were rejected"
    known_demo_pairs = [(26.8467, 80.9462), (26.8, 80.9)]
    for demo_lat, demo_lng in known_demo_pairs:
        if abs(latitude - demo_lat) < 0.00001 and abs(longitude - demo_lng) < 0.00001:
            return False, "Known demo/sample coordinates were rejected"
    return True, ""

def _require_real_coordinates(latitude: Optional[float], longitude: Optional[float]):
    valid, reason = _coordinates_valid(latitude, longitude)
    if not valid:
        print(
            "[mobile:gps] blocked coordinates "
            f"lat_present={latitude is not None} lng_present={longitude is not None} reason={reason}"
        )
        raise HTTPException(status_code=400, detail=reason)

def _normalize_proof_content_type(
    filename: str,
    declared_content_type: Optional[str],
    file_bytes: bytes,
    media_type: str,
) -> Optional[str]:
    declared = (declared_content_type or "").split(";", 1)[0].strip().lower()
    extension = os.path.splitext(filename or "")[1].lower()

    if media_type == "video":
        if declared in ["video/mp4", "video/quicktime"]:
            return declared
        return {
            ".mp4": "video/mp4",
            ".mov": "video/quicktime",
        }.get(extension)

    if file_bytes.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if file_bytes.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if (
        len(file_bytes) >= 12
        and file_bytes[:4] == b"RIFF"
        and file_bytes[8:12] == b"WEBP"
    ):
        return "image/webp"

    extension_type = {
        ".png": "image/png",
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".webp": "image/webp",
    }.get(extension)
    if extension_type:
        return extension_type
    if declared in ["image/png", "image/jpeg", "image/webp"]:
        return declared
    return None

@app.post("/mobile/assistant-turn")
async def mobile_assistant_turn(request: MobileAssistantTurnRequest):
    known_data = dict(request.known_data or {})
    result = plan_assistant_turn(
        request.citizen_id,
        request.user_message or "",
        request.current_state or "idle",
        known_data,
    )

    if result.get("issue_type"):
        result["issue_type"] = _normalize_mobile_issue_type(result["issue_type"])

    validation_status = known_data.get("validation_status")
    validation_confidence = float(known_data.get("validation_confidence") or 0)
    evidence_valid = known_data.get("evidence_valid") is True
    matches_claimed_issue = known_data.get("matches_claimed_issue") is True
    has_location = known_data.get("latitude") is not None and known_data.get("longitude") is not None
    has_media = bool(known_data.get("media_present"))

    if result.get("next_action") == "submit_report":
        if (
            not has_location
            or not has_media
            or validation_status != "verified"
            or not evidence_valid
            or not matches_claimed_issue
            or validation_confidence < 0.65
        ):
            result["next_action"] = "manual_review"
            result["safety_status"] = "block_submit"
            result["requires_user_confirmation"] = True
            result["assistant_reply"] = (
                "I cannot auto-submit this yet because real location, proof, "
                "and successful AI validation are all required. I can submit it for manual review."
            )
            result["reason"] = "Submit blocked by backend safety guard."

    return result

@app.post("/mobile/voice-prepare")
async def mobile_voice_prepare(request: MobileVoicePrepareRequest):
    if not request.transcript or not request.transcript.strip():
        raise HTTPException(status_code=400, detail="Transcript cannot be empty")
    _require_real_coordinates(request.latitude, request.longitude)

    llm_result = analyze_voice_report(
        request.transcript,
        request.latitude,
        request.longitude
    )
    detected_category = _normalize_mobile_issue_type(llm_result.get("detected_category", "other"))
    llm_result["detected_category"] = detected_category
    llm_result["source"] = "mobile_voice_prepare"

    return {
        "success": True,
        "detected_category": detected_category,
        "clean_summary": llm_result.get("clean_summary", request.transcript),
        "urgency_score": llm_result.get("urgency_score", 5),
        "urgency_label": llm_result.get("urgency_label", "medium"),
        "department": llm_result.get("department", "General Civic Team"),
        "needs_proof": True,
        "proof_instruction": f"Please capture a clear photo or short video of the {detected_category.replace('_', ' ')}.",
        "ai_metadata": llm_result
    }

@app.post("/mobile/validate-evidence")
async def mobile_validate_evidence(
    file: UploadFile = File(...),
    media_type: str = Form("image"),
    claimed_issue_type: str = Form(...),
    transcript: str = Form(""),
    latitude: float = Form(...),
    longitude: float = Form(...),
    username: str = Form("mobile_user")
):
    if not file or not file.filename:
        raise HTTPException(status_code=400, detail="Missing proof media")
    _require_real_coordinates(latitude, longitude)
    claimed_issue_type = _normalize_mobile_issue_type(claimed_issue_type)
    media_type = (media_type or "image").lower()
    if media_type not in ["image", "video"]:
        raise HTTPException(status_code=400, detail="media_type must be image or video")

    temp_path = f"mobile_validate_{datetime.utcnow().timestamp()}_{file.filename}"
    try:
        file_bytes = await file.read()
        normalized_content_type = _normalize_proof_content_type(
            file.filename,
            file.content_type,
            file_bytes,
            media_type,
        )
        print(
            "[mobile/validate-evidence] "
            f"endpoint_hit=true file_received={bool(file_bytes)} "
            f"filename={file.filename} declared_content_type={file.content_type} "
            f"normalized_content_type={normalized_content_type} "
            f"file_size={len(file_bytes)} claimed_issue_type={claimed_issue_type} "
            f"transcript_present={bool(transcript and transcript.strip())} "
            f"latitude_present={latitude is not None} longitude_present={longitude is not None} "
            f"gemini_key_present={bool(GEMINI_API_KEY)} gemini_key_prefix={_gemini_key_prefix()} "
            f"openai_key_present={bool(OPENAI_API_KEY)} openai_key_prefix={_openai_key_prefix()} "
            f"gemini_model={GEMINI_MODEL_NAME} loaded_env_path={LOADED_ENV_PATH}"
        )
        if normalized_content_type is None:
            return JSONResponse(
                status_code=422,
                content={
                    "success": False,
                    "requires_manual_review": False,
                    "message": "Unsupported proof file type. Please upload JPG, PNG, WEBP, or MP4.",
                    "validation": {
                        "evidence_valid": False,
                        "confidence": 0.0,
                        "visible_issue": "Unsupported proof file type.",
                        "matches_claimed_issue": False,
                        "detected_issue_type": "none",
                        "mismatch_reason": "Unsupported proof file type. Please upload JPG, PNG, WEBP, or MP4.",
                        "recommendation": "retake_proof",
                        "validation_error_code": "UNSUPPORTED_PROOF_TYPE",
                        "provider": "file_type_check",
                    },
                },
            )
        with open(temp_path, "wb") as f:
            f.write(file_bytes)

        validation = validate_civic_evidence(
            temp_path,
            media_type,
            claimed_issue_type,
            transcript,
            normalized_content_type,
        )

        if not validation.get("evidence_valid"):
            print(
                "[mobile/validate-evidence] "
                f"validation_failed code={validation.get('validation_error_code')} "
                f"recommendation={validation.get('recommendation')} "
                f"confidence={validation.get('confidence')}"
            )
            return JSONResponse(
                status_code=422,
                content={
                    "success": False,
                    "requires_manual_review": validation.get("recommendation") == "manual_review",
                    "message": "The uploaded proof does not clearly match the reported issue.",
                    "validation": validation
                }
            )

        return {
            "success": True,
            "message": "Proof validated. Submitting report...",
            "validation": validation
        }
    finally:
        try:
            if os.path.exists(temp_path):
                os.remove(temp_path)
        except Exception:
            pass

@app.post("/mobile/report-submit")
async def mobile_report_submit(
    file: UploadFile = File(...),
    media_type: str = Form("image"),
    issue_type: str = Form(...),
    description: str = Form(...),
    latitude: float = Form(...),
    longitude: float = Form(...),
    username: str = Form(...),
    validation_json: str = Form("{}"),
    source: str = Form("mobile_voice")
):
    if not username or not username.strip():
        raise HTTPException(status_code=400, detail="Username cannot be empty")
    _require_real_coordinates(latitude, longitude)
    if not file or not file.filename:
        raise HTTPException(status_code=400, detail="Missing proof media")

    issue_type = _normalize_mobile_issue_type(issue_type)
    media_type = (media_type or "image").lower()
    validation = _safe_json_dict(validation_json)
    recommendation = validation.get("recommendation")
    evidence_valid = bool(validation.get("evidence_valid"))
    matches_claimed_issue = validation.get("matches_claimed_issue") is True
    validation_confidence = float(validation.get("confidence") or 0)
    auto_verified = bool(
        media_type == "image"
        and evidence_valid
        and matches_claimed_issue
        and validation_confidence >= 0.65
    )

    if media_type == "image" and not auto_verified and recommendation != "manual_review":
        raise HTTPException(
            status_code=422,
            detail={
                "success": False,
                "requires_manual_review": True,
                "message": "The uploaded proof does not clearly match the reported issue.",
                "validation": validation
            }
        )

    temp_path = f"mobile_submit_{datetime.utcnow().timestamp()}_{file.filename}"
    try:
        with open(temp_path, "wb") as f:
            f.write(await file.read())

        with open(temp_path, "rb") as media:
            media_url = upload_media(media, media_type)

        llm_result = analyze_voice_report(description, latitude, longitude)
        llm_result["source"] = source
        llm_result["validation"] = validation
        llm_result["media_type"] = media_type
        llm_result["validation_status"] = "verified" if auto_verified else "manual_review"
        llm_result["auto_submitted"] = auto_verified
        llm_result["reward_eligible"] = auto_verified
        if not auto_verified:
            llm_result["manual_review_reason"] = (
                validation.get("mismatch_reason")
                or validation.get("reason")
                or validation.get("visible_issue")
                or "Proof could not be auto-verified."
            )

        urgency_score = int(llm_result.get("urgency_score", 5) or 5)
        status = "pending" if auto_verified else "manual_review"

        data = {
            "username": username,
            "issue_type": issue_type,
            "latitude": latitude,
            "longitude": longitude,
            "severity": urgency_score,
            "complaint_desc": description,
            "image_url": media_url,
            "media_url": media_url,
            "media_type": media_type,
            "citizen_id": username,
            "validation_status": llm_result["validation_status"],
            "validation_confidence": validation_confidence,
            "validation_provider": validation.get("provider"),
            "reward_eligible": auto_verified,
            "auto_submitted": auto_verified,
            "embedding": [0.0] * 1280,
            "upvotes": 1,
            "status": status,
            "submitted_at": datetime.utcnow().isoformat(),
            "urgency_score": urgency_score,
            "urgency_label": llm_result.get("urgency_label", "medium"),
            "department": llm_result.get("department", "General Civic Team"),
            "admin_action_recommendation": llm_result.get("admin_action_recommendation", ""),
            "ai_metadata": llm_result,
            "community_confirmations": 0,
            "duplicate_reports": 0,
            "priority_score": urgency_score * 2.0 if status == "pending" else urgency_score
        }

        res = supabase.table("complaints").insert(data).execute()
        if not res.data:
            raise Exception("Failed to insert into Supabase")

        return {
            "success": True,
            "message": "Complaint submitted.",
            "data": res.data[0]
        }
    finally:
        try:
            if os.path.exists(temp_path):
                os.remove(temp_path)
        except Exception:
            pass

@app.post("/voice-report")
async def voice_report(request: VoiceReportRequest):
    if not request.transcript or not request.transcript.strip():
        raise HTTPException(status_code=400, detail="Transcript cannot be empty")
        
    try:
        # 1. LLM via Gemini to normalize voice transcript
        llm_result = analyze_voice_report(
            request.transcript,
            request.latitude,
            request.longitude
        )

        description = llm_result.get("clean_summary", request.transcript)
        issue_type = llm_result.get("detected_category", "other")
        urgency_score = llm_result.get("urgency_score", 5)

        # 2. Add "source": "voice" to ai_metadata
        llm_result["source"] = "voice"

        # 3. DB Insert
        data = {
            "username": request.username,
            "issue_type": issue_type,
            "latitude": request.latitude,
            "longitude": request.longitude,
            "severity": urgency_score,  # No ML model, use urgency as severity
            "complaint_desc": description,
            "image_url": "https://res.cloudinary.com/demo/image/upload/sample.jpg", # Fallback image
            "embedding": [0.0] * 1280,  # Empty embedding
            "upvotes": 1,
            "status": "pending",
            "submitted_at": datetime.utcnow().isoformat(),
            "urgency_score": urgency_score,
            "urgency_label": llm_result.get("urgency_label", "medium"),
            "department": llm_result.get("department", "General Civic Team"),
            "admin_action_recommendation": llm_result.get("admin_action_recommendation", ""),
            "ai_metadata": llm_result,
            "community_confirmations": 0,
            "duplicate_reports": 0,
            "priority_score": urgency_score * 2.0  # Simple priority calculation for voice
        }

        # Store in DB
        res = supabase.table("complaints").insert(data).execute()
        
        if not res.data:
            raise Exception("Failed to insert into Supabase")

        return res.data[0]

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to process voice report: {str(e)}")
