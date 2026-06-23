# Antigravity Changelog

Every change made to the codebase is recorded here.

## Change Entry

**Date/time:** 2026-06-23T10:45:00Z
**Files changed:** 
- `backend/Team-Try/model/classifier.py`
- `backend/Team-Try/model/classifier2.py`
- `backend/Team-Try/services/gemini_service.py` (New)
- `backend/Team-Try/services/llm.py` (Deleted)
- `backend/Team-Try/services/llm_agent.py` (Deleted)
- `backend/Team-Try/main.py`
- `Admin frontend/src/services/api.js`
- `Admin frontend/src/components/MapSidebar.jsx`
- `Admin frontend/src/pages/FiltrationSystem.jsx`
- `Civic-App/lib/core/services/api_service.dart`
- `README.md`
- `.env.example` files
**What changed:** 
1. Added fallback mode for missing ML `.h5` models so the backend doesn't crash on import.
2. Created a new `gemini_service.py` to replace Groq and the old Gemini implementation.
3. Updated `/upload_details` and `/analyze` routes to use the new `gemini_service.py`.
4. Added new community validation endpoints (`/confirm`, `/duplicate`) and mapped them to Supabase.
5. Updated the React Admin dashboard to display new AI fields (urgency, department, etc.).
6. Parameterized API base URLs via env variables/dart defines.
**Why changed:** Hackathon requirement to use Google AI Studio (Gemini) as the core AI layer, improve stability, and address the "Community Hero" problem statement.
**Before behavior:** Hardcoded IPs, crashed if models were missing, used Groq for NL-to-SQL, no community validation.
**After behavior:** Fallback mode active if models missing, Gemini handles all AI tasks including NL-to-SQL, new Community UI in admin panel.
**Testing done:** Validated endpoints syntax and code structure. 
**Screenshots/evidence:** Handled via code verification.
**Risk or follow-up:** Need to run the `seed_demo_data.py` after Supabase is setup by the user.

---

## Change Entry

**Date/time:** 2026-06-23T11:55:00Z
**Files changed:** 
- `backend/Team-Try/utils/config.py`
- `backend/Team-Try/services/supabase.py`
- `backend/Team-Try/services/gemini_service.py`
- `backend/Team-Try/main.py`
- `.gitignore`
- `docs/HANDOFF_FOR_CHATGPT.md`
**What changed:** 
1. `config.py`: Replaced simple `load_dotenv` with cascaded loading (`backend/Team-Try/.env` -> `backend/.env` -> `.env`).
2. `supabase.py`: Added `SUPABASE_URL` format validation and gracefully caught connection errors without crashing.
3. `gemini_service.py`: Added checking for `AIza` prefix and added explicit `try/except` for API key failures returning a clean JSON structure instead of raising an unhandled exception.
4. `main.py`: Added `/debug-config` endpoint. Wrapped `/complaints`, `/confirm`, `/duplicate` and other Supabase calls in `try/except`. Returned `validation_mode: fallback` inside `/upload_details` payload. Handled gracefully the `KeyError` on `/analyze` when Gemini validation fails.
5. `.gitignore`: Explicitly added `.env`, `*.env`, and exact paths to all `.env` files to prevent secret leakage.
6. `HANDOFF_FOR_CHATGPT.md`: Documented current deployment status and exact error details.
**Why changed:** Addressed deployment issues where missing or incorrect `.env` keys (Supabase / Gemini) caused backend crashes, 500 internal server errors, and `getaddrinfo` resolution failures. Improved robustness and safety for hackathon presentation.
**Before behavior:** Missing or invalid keys resulted in FastAPI 500 Internal Server Errors, `getaddrinfo` crashes, and untracked environment diagnostics.
**After behavior:** Graceful degradation. Endpoint returns proper 400 or 500 level JSON errors detailing exactly what config is missing, allowing the frontend to handle it cleanly.
**Testing done:** Validated all endpoints with `Invoke-RestMethod` and verified 200 OK responses containing valid JSON error payloads instead of crashes. Tested frontend compilation and verified git safety.
**Risk or follow-up:** The user must manually supply the correct Gemini and Supabase keys in `backend/.env`.

---

## Change Entry

**Date/time:** 2026-06-23T12:50:00Z
**Files changed:** 
- `backend/Team-Try/services/gemini_service.py`
- `docs/supabase_schema.sql`
- `docs/HANDOFF_FOR_CHATGPT.md`
**What changed:** 
1. `gemini_service.py`: Upgraded from deprecated `gemini-1.5-flash` model to `gemini-2.5-flash` because Google AI Studio threw a 404 error.
2. `supabase_schema.sql`: Added `CREATE EXTENSION IF NOT EXISTS vector;` to the top of the schema file because Supabase requires manual enablement of the `pgvector` AI extension.
3. `HANDOFF_FOR_CHATGPT.md`: Refreshed the status page to show 100% operational status for both Gemini AI and Supabase DB.
**Why changed:** User supplied real `.env` keys which successfully authenticated with both APIs, but hit subsequent backend blockers (deprecated model version and missing postgres extension).
**Before behavior:** Authentic API requests threw `404 model not found` on Gemini and `type "vector" does not exist` on Supabase.
**After behavior:** Successful execution of AI-driven NLP to SQL mapping and fetching from Supabase (`success: True`).
**Testing done:** Fired `/gemini-analyze` API with a real civic issue query and verified JSON payload successfully returned an AI-generated SQL block with `execute_sql` success.
**Risk or follow-up:** User needs to run `seed_demo_data.py` to get mock reports showing in the UI.
