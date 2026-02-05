-- V5__social_enhancements.sql
-- Add missing social graph fields

-- Add reason and note to block_list
ALTER TABLE block_list ADD COLUMN IF NOT EXISTS reason VARCHAR(30);
ALTER TABLE block_list ADD COLUMN IF NOT EXISTS note VARCHAR(200);

-- Add favorite and hidden flags to friendship
ALTER TABLE friendship ADD COLUMN IF NOT EXISTS is_favorite_from BOOLEAN DEFAULT FALSE;
ALTER TABLE friendship ADD COLUMN IF NOT EXISTS is_favorite_to BOOLEAN DEFAULT FALSE;
ALTER TABLE friendship ADD COLUMN IF NOT EXISTS is_hidden_from BOOLEAN DEFAULT FALSE;
ALTER TABLE friendship ADD COLUMN IF NOT EXISTS is_hidden_to BOOLEAN DEFAULT FALSE;

-- Add OTP max_attempts
ALTER TABLE auth_otp ADD COLUMN IF NOT EXISTS max_attempts INT DEFAULT 5;

-- Add indexes for favorites
CREATE INDEX IF NOT EXISTS idx_friendship_favorite_from ON friendship(user_id_from) WHERE is_favorite_from = TRUE;
CREATE INDEX IF NOT EXISTS idx_friendship_favorite_to ON friendship(user_id_to) WHERE is_favorite_to = TRUE;
