# Implementation Report

* **Problem statement selected:** Community Hero - Hyperlocal Problem Solver
* **Solution overview:** A full-stack civic issue reporting platform that allows citizens to report issues via mobile (Flutter), validates images via AI/ML (FastAPI + MobileNetV2), generates structured insights via Gemini, and provides an admin dashboard (React) for tracking and resolving these issues. Community members can validate and upvote issues to increase their priority.
* **Key features:** Mobile image capture with GPS tagging, AI-powered issue routing and summarization, severity/priority scoring, community confirmations, duplicate detection, and natural language analytics queries.
* **Technologies used:** Flutter, FastAPI, React, Supabase (PostgreSQL), Cloudinary, TensorFlow, OpenCV.
* **Google technologies utilized:** Google AI Studio (Gemini 2.5 Flash).
* **Gemini use cases:** (1) Analyzing user-uploaded images and descriptions to extract a clean summary, urgency score, department routing, and safety notes. (2) Translating natural language queries from admins into secure PostgreSQL statements to generate dynamic charts.
* **System architecture:** Mobile App -> FastAPI Backend -> Gemini AI Studio -> Supabase DB -> React Admin Dashboard.
* **User flow:** Citizen spots an issue -> Takes a photo using the CityPulse app -> AI analyzes the severity and extracts details -> Citizen confirms submission. Citizens can also upvote existing nearby issues to increase priority.
* **Admin flow:** Admin logs into the React dashboard -> Views the geo-spatial Leaflet map -> Prioritizes issues based on the AI-assigned Priority Score and Department -> Updates status with a "resolved image" -> Uses NL query for weekly reports.
* **Impact:** Eliminates fraudulent complaints, automates routing to specific departments, and objectively prioritizes issues based on visual damage + community impact.
* **Community Hero Extensions:** Added a Public Community Feed (`/community`) for citizens to track and validate reports, and a Citizen Leaderboard (`/leaderboard`) that gamifies civic engagement with badges (Community Hero, Streetlight Watcher, etc.).
* **Predictive Analytics:** Augmented the dashboard with Predictive Hotspot cards, offering at-a-glance metrics on critical issues, confirmations, and top categories, including a Gemini Insight generator for high-level summaries.
* **Accessibility Extension (Vapi Voice Reporter):** Integrated an optional `@vapi-ai/web` assistant in the React dashboard. Citizens can verbally describe issues, and Gemini normalizes the raw transcript directly into the civic schema. Vapi serves as the accessibility layer, while Gemini remains the core intelligence layer.
* **Video/Media Support:** Upgraded the Supabase schema to natively support `media_url` and `media_type`, providing an architecture-ready path for future video proof uploads.
* **Limitations:** ML models are large and currently running in a simulated "Fallback Mode" for the hackathon deployment to ensure stability. True real-world deployment requires hosting the heavy `.h5` files or moving inference to a cloud function.
* **Future scope:** `pgvector` is now actively enabled in the Supabase schema for advanced semantic searches. Future scope involves fully automating the duplicate detection pipeline, push notifications via Firebase Cloud Messaging, and an offline submission queue for the mobile app.
