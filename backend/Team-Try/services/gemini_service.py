# services/gemini_service.py

import google.generativeai as genai
import json
import re
from utils.config import GEMINI_API_KEY
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

# We can use gemini-1.5-pro or gemini-2.5-flash as the core model
model = genai.GenerativeModel("gemini-2.5-flash")

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
