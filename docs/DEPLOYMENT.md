# Deployment Guide: CityPulse / Community Hero

This guide provides instructions for deploying the CityPulse application, focusing on the backend, admin dashboard, and database.

## 1. Database (Supabase)
1. Create a new Supabase project at [supabase.com](https://supabase.com/).
2. Go to the SQL Editor and execute the contents of `docs/supabase_schema.sql`.
3. Copy the `Project URL` and `anon public key` from Settings > API.
4. Set these as `SUPABASE_URL` and `SUPABASE_KEY` environment variables.

## 2. AI & Media Services
1. **Google AI Studio**: Get an API key for Gemini. Set as `GEMINI_API_KEY`.
2. **Cloudinary**: Get your Cloud Name, API Key, and API Secret. Set as `CLOUD_NAME`, `CLOUD_API_KEY`, `CLOUD_API_SECRET`.

## 3. Backend Deployment (Google Cloud Run Preferred)
To deploy the FastAPI backend using Google Cloud Run:
1. Ensure the `requirements.txt` is updated.
2. Build the Docker container (create a simple `Dockerfile` in `backend/Team-Try`):
   ```dockerfile
   FROM python:3.10-slim
   WORKDIR /app
   COPY requirements.txt .
   RUN pip install -r requirements.txt
   COPY Team-Try/ .
   CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
   ```
3. Run `gcloud run deploy citypulse-backend --source . --port 8080`
4. Provide all environment variables from steps 1 and 2 during deployment.

## 4. Admin Frontend Deployment
1. Set the `VITE_API_BASE_URL` in your deployment environment (e.g., Vercel, Netlify) to the deployed backend URL.
2. Build command: `npm run build`
3. Output directory: `dist`

## 5. Testing API Endpoints

Once deployed, you can verify the backend is functioning using these sample curl requests:

**Check Health**
```bash
curl -X GET <backend_url>/health
```

**Get All Complaints**
```bash
curl -X GET <backend_url>/complaints
```

**Natural Language Analytics**
```bash
curl -X POST <backend_url>/gemini-analyze \
  -H "Content-Type: application/json" \
  -d '{"query": "Show me pothole complaints by severity"}'
```

**Community Verification (Confirm)**
```bash
curl -X POST <backend_url>/complaints/1/confirm
```

**Community Verification (Duplicate)**
```bash
curl -X POST <backend_url>/complaints/1/duplicate
```

## 6. Frontend Testing
1. Connect the Flutter app by updating `API_BASE_URL` using `--dart-define=API_BASE_URL=<backend_url>` when building the APK.
