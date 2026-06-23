-- Supabase Schema for Community Hero / CityPulse

-- Table: complaints
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE complaints (
    id SERIAL PRIMARY KEY,
    username TEXT NOT NULL,
    issue_type TEXT NOT NULL,
    latitude FLOAT8 NOT NULL,
    longitude FLOAT8 NOT NULL,
    severity INTEGER,
    complaint_desc TEXT,
    image_url TEXT,
    resolved_image_url TEXT,
    embedding vector(1280), -- or jsonb if pgvector is not enabled
    upvotes INTEGER DEFAULT 1,
    status TEXT DEFAULT 'pending',
    submitted_at TIMESTAMPTZ DEFAULT now(),
    
    -- New Community Hero AI Fields
    urgency_score INTEGER DEFAULT 5,
    urgency_label TEXT DEFAULT 'medium',
    department TEXT DEFAULT 'General Civic Team',
    admin_action_recommendation TEXT,
    ai_metadata JSONB,
    community_confirmations INTEGER DEFAULT 0,
    duplicate_reports INTEGER DEFAULT 0,
    duplicate_of INTEGER REFERENCES complaints(id),
    trust_score NUMERIC DEFAULT 0,
    priority_score NUMERIC DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Analytics RPC required for NL to SQL
CREATE OR REPLACE FUNCTION execute_sql(query text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result json;
BEGIN
  EXECUTE 'SELECT json_agg(t) FROM (' || query || ') t' INTO result;
  RETURN result;
END;
$$;
