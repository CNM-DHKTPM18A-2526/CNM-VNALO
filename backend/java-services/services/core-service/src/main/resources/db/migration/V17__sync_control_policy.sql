-- Sync-control policy flags for cross-device data restrictions
ALTER TABLE user_setting
    ADD COLUMN IF NOT EXISTS sync_enabled BOOLEAN DEFAULT TRUE;

ALTER TABLE user_setting
    ADD COLUMN IF NOT EXISTS web_restricted_mode BOOLEAN DEFAULT FALSE;
