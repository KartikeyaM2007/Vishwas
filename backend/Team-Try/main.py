from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from services.cloudinary import upload_image
from services.gemini_service import analyze_civic_issue, generate_sql_and_chart, analyze_voice_report
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
from utils.config import LOADED_ENV_PATH, SUPABASE_URL, SUPABASE_KEY, GEMINI_API_KEY
from model.classifier import process_image, FALLBACK_MODE as classifier_fallback
from model.classifier2 import validate_and_extract_features, FALLBACK_MODE as classifier2_fallback
import os
import traceback

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
    if latitude < -90 or latitude > 90 or longitude < -180 or longitude > 180:
        raise HTTPException(status_code=400, detail="Invalid latitude or longitude")
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
                upvotes,
                status,
                submitted_at,
                community_confirmations,
                duplicate_reports,
                priority_score,
                department,
                urgency_score,
                urgency_label
            """)\
            .order("submitted_at", desc=True)\
            .execute()

        return {
            "count": len(response.data),
            "data": response.data
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
        return {"success": True, "data": res.data[0]}
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
