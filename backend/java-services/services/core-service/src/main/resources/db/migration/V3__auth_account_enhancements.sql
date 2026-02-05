-- V3__auth_account_enhancements.sql
-- Add missing fields from design documentation

-- Add Firebase UID for Firebase Auth integration
ALTER TABLE auth_account ADD COLUMN IF NOT EXISTS firebase_uid VARCHAR(128) UNIQUE;

-- Add account locking fields
ALTER TABLE auth_account ADD COLUMN IF NOT EXISTS locked_until TIMESTAMPTZ;
ALTER TABLE auth_account ADD COLUMN IF NOT EXISTS failed_login_count INT DEFAULT 0;

-- Add device tracking for last login
ALTER TABLE auth_account ADD COLUMN IF NOT EXISTS last_login_device_id VARCHAR(100);

-- Add status index for better query performance
CREATE INDEX IF NOT EXISTS idx_auth_account_status ON auth_account(status);
