import os
import json
from datetime import datetime, timedelta
import random
from services.supabase import supabase
from dotenv import load_dotenv

load_dotenv()

if not os.getenv("SUPABASE_URL") or not os.getenv("SUPABASE_KEY"):
    print("Supabase credentials not found. Please set SUPABASE_URL and SUPABASE_KEY in .env.")
    print("Exiting gracefully.")
    exit(0)

print("Seeding demo complaints into Supabase...")

categories = ["pothole", "garbage", "streetlight", "water_leak"]
departments = ["Road Works", "Sanitation", "Electrical", "Water Supply"]
urgency_labels = ["low", "medium", "high", "critical"]

demo_data = []

for i in range(5):
    issue = random.choice(categories)
    severity = random.randint(3, 9)
    urgency = random.randint(3, 9)
    confirmations = random.randint(0, 10)
    
    data = {
        "username": f"citizen_{i}",
        "issue_type": issue,
        "latitude": 19.0760 + random.uniform(-0.05, 0.05),
        "longitude": 72.8777 + random.uniform(-0.05, 0.05),
        "severity": severity,
        "complaint_desc": f"This is a demo {issue} reported by a citizen.",
        "image_url": "https://res.cloudinary.com/demo/image/upload/sample.jpg",
        "upvotes": confirmations + 1,
        "status": random.choice(["pending", "onprogress", "solved"]),
        "submitted_at": (datetime.utcnow() - timedelta(days=random.randint(0, 7))).isoformat(),
        "urgency_score": urgency,
        "urgency_label": urgency_labels[urgency // 3],
        "department": departments[categories.index(issue)],
        "admin_action_recommendation": f"Inspect the {issue} and schedule repairs.",
        "community_confirmations": confirmations,
        "duplicate_reports": 0,
        "priority_score": severity + urgency + (confirmations * 0.5)
    }
    demo_data.append(data)

try:
    response = supabase.table("complaints").insert(demo_data).execute()
    print(f"Successfully inserted {len(response.data)} records.")
except Exception as e:
    print(f"Error seeding data: {e}")
