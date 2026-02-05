-- V3__schema_improvements.sql
-- Schema improvements to align with VNALO_Complete_Database_Schema.md

-- ==================== AUTH ACCOUNT IMPROVEMENTS ====================

-- Add missing fields from schema design
ALTER TABLE auth_account ADD COLUMN IF NOT EXISTS firebase_uid VARCHAR(128) UNIQUE;
ALTER TABLE auth_account ADD COLUMN IF NOT EXISTS locked_until TIMESTAMP WITH TIME ZONE;
ALTER TABLE auth_account ADD COLUMN IF NOT EXISTS failed_login_count INTEGER DEFAULT 0;
ALTER TABLE auth_account ADD COLUMN IF NOT EXISTS last_login_device_id VARCHAR(100);

-- Add index for status queries
CREATE INDEX IF NOT EXISTS idx_auth_account_status ON auth_account(status);

-- ==================== AUTH REFRESH TOKEN IMPROVEMENTS ====================

-- Add missing device info fields
ALTER TABLE auth_refresh_token ADD COLUMN IF NOT EXISTS device_name VARCHAR(100);
ALTER TABLE auth_refresh_token ADD COLUMN IF NOT EXISTS platform VARCHAR(20);
ALTER TABLE auth_refresh_token ADD COLUMN IF NOT EXISTS ip_address VARCHAR(45);
ALTER TABLE auth_refresh_token ADD COLUMN IF NOT EXISTS user_agent TEXT;

-- Add check constraint for platform (handled by Java enum)
-- CREATE INDEX for compound queries
CREATE INDEX IF NOT EXISTS idx_refresh_token_device ON auth_refresh_token(device_id);
CREATE INDEX IF NOT EXISTS idx_refresh_token_expires ON auth_refresh_token(account_id, expires_at);

-- ==================== AUTH OTP IMPROVEMENTS ====================

-- Add max_attempts field from schema
ALTER TABLE auth_otp ADD COLUMN IF NOT EXISTS max_attempts INTEGER DEFAULT 5;

-- ==================== USER PROFILE IMPROVEMENTS ====================

-- Add missing fields from schema design
ALTER TABLE user_profile ADD COLUMN IF NOT EXISTS region VARCHAR(100);
ALTER TABLE user_profile ADD COLUMN IF NOT EXISTS is_official_account BOOLEAN DEFAULT FALSE;
ALTER TABLE user_profile ADD COLUMN IF NOT EXISTS follower_count INTEGER DEFAULT 0;

-- Add index for verified/official accounts
CREATE INDEX IF NOT EXISTS idx_profile_verified ON user_profile(is_verified) WHERE is_verified = TRUE;
CREATE INDEX IF NOT EXISTS idx_profile_official ON user_profile(is_official_account) WHERE is_official_account = TRUE;

-- ==================== USER PRIVACY SETTING IMPROVEMENTS ====================

-- Add missing visibility fields from schema
ALTER TABLE user_privacy_setting ADD COLUMN IF NOT EXISTS allow_search_by_phone BOOLEAN DEFAULT TRUE;
ALTER TABLE user_privacy_setting ADD COLUMN IF NOT EXISTS allow_search_by_qr BOOLEAN DEFAULT TRUE;
ALTER TABLE user_privacy_setting ADD COLUMN IF NOT EXISTS allow_stranger_message BOOLEAN DEFAULT FALSE;
ALTER TABLE user_privacy_setting ADD COLUMN IF NOT EXISTS last_seen_visibility VARCHAR(20) DEFAULT 'FRIENDS';
ALTER TABLE user_privacy_setting ADD COLUMN IF NOT EXISTS story_visibility VARCHAR(20) DEFAULT 'FRIENDS';
ALTER TABLE user_privacy_setting ADD COLUMN IF NOT EXISTS timeline_visibility VARCHAR(20) DEFAULT 'FRIENDS';
ALTER TABLE user_privacy_setting ADD COLUMN IF NOT EXISTS allow_add_to_group VARCHAR(20) DEFAULT 'FRIENDS';
ALTER TABLE user_privacy_setting ADD COLUMN IF NOT EXISTS allow_video_call VARCHAR(20) DEFAULT 'FRIENDS';

-- ==================== NEW TABLE: user_setting ====================
-- User preferences table from schema design

CREATE TABLE IF NOT EXISTS user_setting (
    user_id UUID PRIMARY KEY,
    language VARCHAR(10) DEFAULT 'vi',
    theme VARCHAR(20) DEFAULT 'LIGHT',
    font_size VARCHAR(20) DEFAULT 'MEDIUM',
    notification_sound BOOLEAN DEFAULT TRUE,
    notification_vibrate BOOLEAN DEFAULT TRUE,
    notification_preview BOOLEAN DEFAULT TRUE,
    auto_download_image BOOLEAN DEFAULT TRUE,
    auto_download_video BOOLEAN DEFAULT FALSE,
    auto_download_file BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE
);

-- ==================== NEW TABLE: contact_sync ====================
-- Contact synchronization table for phone contacts

CREATE TABLE IF NOT EXISTS contact_sync (
    sync_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    phone_number VARCHAR(20) NOT NULL,
    contact_name VARCHAR(100),
    matched_user_id UUID,
    invited_at TIMESTAMP WITH TIME ZONE,
    synced_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT uk_contact_sync UNIQUE (user_id, phone_number)
);

CREATE INDEX IF NOT EXISTS idx_contact_user ON contact_sync(user_id);
CREATE INDEX IF NOT EXISTS idx_contact_matched ON contact_sync(matched_user_id) WHERE matched_user_id IS NOT NULL;

-- ==================== FRIENDSHIP IMPROVEMENTS ====================

-- Add favorite and hidden features from schema
ALTER TABLE friendship ADD COLUMN IF NOT EXISTS is_favorite_from BOOLEAN DEFAULT FALSE;
ALTER TABLE friendship ADD COLUMN IF NOT EXISTS is_favorite_to BOOLEAN DEFAULT FALSE;
ALTER TABLE friendship ADD COLUMN IF NOT EXISTS is_hidden_from BOOLEAN DEFAULT FALSE;
ALTER TABLE friendship ADD COLUMN IF NOT EXISTS is_hidden_to BOOLEAN DEFAULT FALSE;

-- Add indexes for favorite friends
CREATE INDEX IF NOT EXISTS idx_friendship_favorite_from ON friendship(user_id_from) WHERE is_favorite_from = TRUE;
CREATE INDEX IF NOT EXISTS idx_friendship_favorite_to ON friendship(user_id_to) WHERE is_favorite_to = TRUE;

-- ==================== BLOCK LIST IMPROVEMENTS ====================

-- Add reason and note fields from schema
ALTER TABLE block_list ADD COLUMN IF NOT EXISTS reason VARCHAR(30);
ALTER TABLE block_list ADD COLUMN IF NOT EXISTS note VARCHAR(200);

-- ==================== ADD FOREIGN KEYS FOR NEW TABLES ====================

-- user_setting -> user_profile
ALTER TABLE user_setting
    ADD CONSTRAINT fk_setting_profile
    FOREIGN KEY (user_id) REFERENCES user_profile(id) ON DELETE CASCADE;

-- contact_sync -> user_profile (owner)
ALTER TABLE contact_sync
    ADD CONSTRAINT fk_contact_user
    FOREIGN KEY (user_id) REFERENCES user_profile(id) ON DELETE CASCADE;

-- contact_sync -> user_profile (matched user, optional)
ALTER TABLE contact_sync
    ADD CONSTRAINT fk_contact_matched
    FOREIGN KEY (matched_user_id) REFERENCES user_profile(id) ON DELETE SET NULL;
