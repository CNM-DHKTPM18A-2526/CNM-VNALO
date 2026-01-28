-- V1__init_schema.sql
-- Core Service Database Schema

-- ==================== AUTH TABLES ====================

CREATE TABLE auth_account (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone VARCHAR(20) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    password_updated_at TIMESTAMP WITH TIME ZONE,
    status VARCHAR(30) NOT NULL DEFAULT 'PENDING_VERIFICATION',
    last_login_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_auth_account_phone ON auth_account(phone);

CREATE TABLE auth_refresh_token (
    token_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL,
    token_hash VARCHAR(255) NOT NULL UNIQUE,
    device_id VARCHAR(100),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    revoked_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_refresh_token_account ON auth_refresh_token(account_id);
CREATE INDEX idx_refresh_token_hash ON auth_refresh_token(token_hash);

CREATE TABLE auth_otp (
    otp_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    target VARCHAR(100) NOT NULL,
    purpose VARCHAR(30) NOT NULL,
    otp_hash VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    attempts INTEGER DEFAULT 0,
    verified_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_otp_target_purpose ON auth_otp(target, purpose);

-- ==================== USER TABLES ====================

CREATE TABLE user_profile (
    id UUID PRIMARY KEY,
    display_name VARCHAR(100) NOT NULL,
    avatar_url VARCHAR(500),
    gender VARCHAR(20) DEFAULT 'UNKNOWN',
    dob DATE,
    cover_url VARCHAR(500),
    status_message_type VARCHAR(20),
    status_message VARCHAR(200),
    bio VARCHAR(500),
    qr_code_url VARCHAR(500),
    is_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_user_profile_display_name ON user_profile(display_name);

CREATE TABLE user_privacy_setting (
    user_id UUID PRIMARY KEY,
    display_birthday VARCHAR(20) DEFAULT 'DAY_MONTH',
    birthday_notification_enabled BOOLEAN DEFAULT TRUE,
    show_online_status BOOLEAN DEFAULT TRUE,
    allow_messaging BOOLEAN DEFAULT TRUE,
    allow_calling VARCHAR(20) DEFAULT 'EVERYONE',
    allow_seen_and_comment VARCHAR(20) DEFAULT 'EVERYONE',
    allow_friend_request_by_phone BOOLEAN DEFAULT TRUE,
    allow_friend_request_by_qr_code BOOLEAN DEFAULT TRUE,
    allow_friend_request_by_shared_group BOOLEAN DEFAULT TRUE,
    allow_friend_request_by_bio BOOLEAN DEFAULT TRUE,
    allow_friend_request_by_suggestion BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE
);

-- ==================== SOCIAL TABLES ====================

CREATE TABLE friend_request (
    request_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id_from UUID NOT NULL,
    user_id_to UUID NOT NULL,
    message VARCHAR(200),
    source VARCHAR(30),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    responded_at TIMESTAMP WITH TIME ZONE,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING'
);

CREATE INDEX idx_friend_request_to_user ON friend_request(user_id_to, status);
CREATE INDEX idx_friend_request_from_user ON friend_request(user_id_from);

CREATE TABLE friendship (
    friendship_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id_from UUID NOT NULL,
    user_id_to UUID NOT NULL,
    source VARCHAR(30),
    nickname_from VARCHAR(50),
    nickname_to VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_friendship_users UNIQUE (user_id_from, user_id_to)
);

CREATE INDEX idx_friendship_user_from ON friendship(user_id_from);
CREATE INDEX idx_friendship_user_to ON friendship(user_id_to);

CREATE TABLE block_list (
    block_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blocker_id UUID NOT NULL,
    blocked_id UUID NOT NULL,
    block_messages BOOLEAN DEFAULT TRUE,
    block_calls BOOLEAN DEFAULT TRUE,
    block_and_hide_logs BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_block_list UNIQUE (blocker_id, blocked_id)
);

CREATE INDEX idx_block_list_blocker ON block_list(blocker_id);
CREATE INDEX idx_block_list_blocked ON block_list(blocked_id);
