-- V4__auth_token_device_info.sql
-- Add device information to refresh tokens for multi-device management

-- Add device details
ALTER TABLE auth_refresh_token ADD COLUMN IF NOT EXISTS device_name VARCHAR(100);
ALTER TABLE auth_refresh_token ADD COLUMN IF NOT EXISTS platform VARCHAR(20);
ALTER TABLE auth_refresh_token ADD COLUMN IF NOT EXISTS ip_address VARCHAR(45);
ALTER TABLE auth_refresh_token ADD COLUMN IF NOT EXISTS user_agent TEXT;

-- Add platform check constraint
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_platform'
    ) THEN
        ALTER TABLE auth_refresh_token ADD CONSTRAINT chk_platform 
            CHECK (platform IS NULL OR platform IN ('ANDROID', 'IOS', 'WEB', 'PC'));
    END IF;
END $$;

-- Add index for device lookup
CREATE INDEX IF NOT EXISTS idx_refresh_token_device ON auth_refresh_token(device_id);
