-- Admin review queue, audit log, and Reddit-style comments for Community Hero / CityPulse.
-- Run this in the Supabase SQL Editor after the base complaints table exists.

ALTER TABLE complaints
ADD COLUMN IF NOT EXISTS media_url TEXT,
ADD COLUMN IF NOT EXISTS media_type TEXT DEFAULT 'image',
ADD COLUMN IF NOT EXISTS validation_status TEXT DEFAULT 'pending',
ADD COLUMN IF NOT EXISTS validation_confidence NUMERIC,
ADD COLUMN IF NOT EXISTS validation_provider TEXT,
ADD COLUMN IF NOT EXISTS reward_eligible BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS auto_submitted BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS citizen_id TEXT,
ADD COLUMN IF NOT EXISTS resolved_at TIMESTAMPTZ;

CREATE TABLE IF NOT EXISTS complaint_audit_logs (
    id BIGSERIAL PRIMARY KEY,
    complaint_id INTEGER NOT NULL REFERENCES complaints(id) ON DELETE CASCADE,
    actor_id TEXT DEFAULT 'admin',
    actor_role TEXT DEFAULT 'admin',
    action TEXT NOT NULL,
    old_status TEXT,
    new_status TEXT,
    note TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_complaint_audit_logs_complaint_id
ON complaint_audit_logs(complaint_id);

CREATE TABLE IF NOT EXISTS complaint_comments (
    id BIGSERIAL PRIMARY KEY,
    complaint_id INTEGER NOT NULL REFERENCES complaints(id) ON DELETE CASCADE,
    parent_comment_id BIGINT REFERENCES complaint_comments(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL,
    username TEXT NOT NULL,
    user_role TEXT DEFAULT 'citizen',
    body TEXT NOT NULL CHECK (char_length(body) <= 1000),
    is_verified_user BOOLEAN DEFAULT FALSE,
    upvotes INTEGER DEFAULT 0,
    downvotes INTEGER DEFAULT 0,
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_complaint_comments_complaint_id
ON complaint_comments(complaint_id);

CREATE INDEX IF NOT EXISTS idx_complaint_comments_parent_comment_id
ON complaint_comments(parent_comment_id);
