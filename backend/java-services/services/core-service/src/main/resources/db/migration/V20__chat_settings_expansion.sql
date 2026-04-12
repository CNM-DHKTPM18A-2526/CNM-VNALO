-- ============================================================
-- V20: Chat Settings Expansion
-- Adds columns for Personal/Global Wallpapers and Conversation Settings
-- ============================================================

-- Ensure wallpaper_url exists in conversation (Global)
ALTER TABLE conversation ADD COLUMN IF NOT EXISTS wallpaper_url VARCHAR(500);

-- Add settings and personal wallpaper to conversation_inbox
ALTER TABLE conversation_inbox ADD COLUMN IF NOT EXISTS wallpaper_url VARCHAR(500);
ALTER TABLE conversation_inbox ADD COLUMN IF NOT EXISTS is_favorite BOOLEAN DEFAULT FALSE;
ALTER TABLE conversation_inbox ADD COLUMN IF NOT EXISTS auto_delete_seconds INT DEFAULT 0;
ALTER TABLE conversation_inbox ADD COLUMN IF NOT EXISTS notify_call BOOLEAN DEFAULT TRUE;

-- Add index to facilitate "Favorites" filter
CREATE INDEX IF NOT EXISTS idx_inbox_favorite ON conversation_inbox(user_id, is_favorite) WHERE is_favorite = TRUE;
