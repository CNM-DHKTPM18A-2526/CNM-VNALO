-- ============================================================
-- V19: Align Messaging Entities
-- Adds missing columns required by message-service TypeORM entities
-- ============================================================

-- Add wallpaper_url to conversation table
ALTER TABLE conversation ADD COLUMN IF NOT EXISTS wallpaper_url VARCHAR(500);

-- Add history_cleared_at to conversation_inbox table
ALTER TABLE conversation_inbox ADD COLUMN IF NOT EXISTS history_cleared_at TIMESTAMPTZ;
