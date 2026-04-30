-- V25: Add tables for AI Mascot Settings and Long-term History
-- Migration Date: 2026-04-29

-- Table to store user's AI Mascot preferences
CREATE TABLE IF NOT EXISTS user_mascot_settings (
    user_id UUID PRIMARY KEY,
    mascot_id VARCHAR(50) DEFAULT 'default_mascot',
    mascot_name VARCHAR(100),
    mascot_type VARCHAR(20) DEFAULT '2D', -- '2D' or '3D'
    personality_type VARCHAR(50) DEFAULT 'friendly',
    primary_color VARCHAR(20) DEFAULT '#4A90E2',
    language_code VARCHAR(10) DEFAULT 'vi', -- Default to Vietnamese
    custom_instructions TEXT,
    metadata JSONB, -- For future flexible settings (voice_id, outfit_id, etc.)
    is_active BOOLEAN DEFAULT TRUE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Table to store permanent AI chat history
CREATE TABLE IF NOT EXISTS ai_chat_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    conversation_id UUID NOT NULL,
    role VARCHAR(20) NOT NULL, -- 'user' or 'assistant'
    content TEXT NOT NULL,
    message_type VARCHAR(20) DEFAULT 'text', -- 'text', 'image', 'command'
    emotion VARCHAR(50) DEFAULT 'thinking',
    metadata JSONB, -- Store LLM metadata (token usage, tool calls, etc.)
    provider VARCHAR(50), 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_ai_history_user_conv ON ai_chat_history(user_id, conversation_id);
