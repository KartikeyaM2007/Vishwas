# Community Hero: Features & Capabilities

**Community Hero** (formerly CityPulse / Vishwas) is an AI-powered, full-stack hyperlocal civic issue reporting, validation, and resolution platform.

## 🎯 The Problem We Solve
City administrations and municipal corporations face overwhelming volumes of civic complaints (potholes, broken streetlights, waterlogging, garbage dumps, etc.). Currently, this process is plagued by:
1. **Unstructured Data:** Complaints lack context, severity metrics, and proper categorization.
2. **Duplicate & Fake Reports:** Multiple citizens report the exact same issue, or submit fraudulent/spam images, clogging the system.
3. **Manual Triage:** Administrators spend thousands of hours manually routing complaints to the electrical, civil, or sanitation departments.
4. **Lack of Community Trust:** Citizens feel disconnected because there is no transparent tracking or gamified involvement in neighborhood maintenance.

## 💡 Our Solution
Community Hero bridges the gap between citizens and city admins. We empower citizens with a mobile app to snap and report issues, while leveraging **Google Gemini AI** to instantly validate, score, and route those issues to a powerful, geo-spatial Admin Dashboard.

---

## 🚀 Key Features

### 1. AI-Powered Issue Triage (Google Gemini 2.5 Flash)
* **Automated Categorization:** The AI analyzes the uploaded image and text description to instantly extract the issue type (e.g., electrical, sanitation, road quality).
* **Urgency & Severity Scoring:** Gemini assigns a 1-10 urgency score and labels it (low, medium, high, critical) based on visual damage and described hazards.
* **Smart Department Routing:** Automatically recommends the correct municipal department to handle the resolution.

### 2. Community Gamification & Validation
* **Public Community Feed (`/community`):** A public-facing feed of all civic issues, offering transparency into city conditions.
* **Citizen Leaderboard (`/leaderboard`):** Gamifies engagement by calculating top reporters and issuing badges (e.g., Community Hero, Streetlight Watcher) based on activity.
* **Priority Score Algorithm:** Issues are ranked on the admin dashboard not just by when they were submitted, but via a dynamic `priority_score` combining AI severity and community upvotes.
* **Crowdsourced Verification:** Citizens can "Confirm" existing complaints or mark them as "Duplicates". This builds a `trust_score` and prevents admin overload.

### 3. Geo-Spatial Admin Dashboard (React + Vite)
* **Live Incident Map:** Visualizes all active, pending, and resolved complaints on an interactive Leaflet map using GPS coordinates.
* **Filtration System:** Admins can instantly filter issues by the AI-generated urgency labels, departments, or community confirmation counts.

### 4. Natural Language Analytics (NL-to-SQL)
* **Chat with your Database:** Instead of building complex reports, admins can type plain English queries (e.g., *"Show me the most critical issues reported this week"*). 
* **Seamless AI Translation:** Gemini seamlessly translates these natural language queries into secure PostgreSQL statements, fetches data directly from Supabase, and dynamically renders bar charts and data tables.

### 5. Predictive Hotspots & Impact Cards
* **At-a-glance Metrics:** Visual dashboard cards embedded over the map showing Total Issues, Critical Alerts, Confirmations, and Top Categories.
* **Gemini Insight Generator:** A one-click button that triggers a real-time Gemini LLM query to summarize the current civic landscape.

### 6. Voice Civic Reporter (Vapi Integration)
* **Accessibility-First:** Citizens can click a microphone and verbally describe the civic issue instead of typing.
* **Conversational Parsing:** The app integrates an optional Vapi.ai assistant to listen to the citizen, and utilizes Gemini to extract structure directly from the raw transcript.

### 7. Future-Ready Architecture
* **Vector Embeddings (`pgvector`):** The Supabase database is structurally wired with vector embeddings, allowing for advanced semantic searches and visual-similarity duplicate detection in the future.
* **Video-Proof Schema:** The database natively supports `media_url` and `media_type` to allow future scalability into video-based civic complaints.
* **Fallback ML Safety:** Edge-case handling ensures the platform never crashes even if heavy local ML models (like TensorFlow `.h5` files) are offline or missing.

---

## 🛠️ Tech Stack
* **Frontend (Citizen):** Flutter (Mobile)
* **Frontend (Admin):** React + Vite SPA
* **Backend:** FastAPI (Python)
* **Database:** Supabase (PostgreSQL with `pgvector` enabled)
* **AI Engine:** Google AI Studio (Gemini 2.5 Flash)
* **Media Storage:** Cloudinary
