-- V6__user_profile_enhancements.sql
-- Add missing user profile fields

-- Add region, official account, and follower count
ALTER TABLE user_profile ADD COLUMN IF NOT EXISTS region VARCHAR(100);
ALTER TABLE user_profile ADD COLUMN IF NOT EXISTS is_official_account BOOLEAN DEFAULT FALSE;
ALTER TABLE user_profile ADD COLUMN IF NOT EXISTS follower_count INT DEFAULT 0;

-- Add index for official accounts
CREATE INDEX IF NOT EXISTS idx_profile_official ON user_profile(is_official_account) WHERE is_official_account = TRUE;
