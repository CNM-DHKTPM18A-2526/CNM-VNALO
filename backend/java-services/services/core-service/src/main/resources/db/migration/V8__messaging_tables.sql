-- ============================================================
-- V8: Messaging Tables Migration
-- Creates conversation, message, and inbox tables for message-service
-- ============================================================

-- Conversation table
CREATE TABLE IF NOT EXISTS conversation (
    conversation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type VARCHAR(20) NOT NULL CHECK (type IN ('DIRECT', 'GROUP')),
    title VARCHAR(100),
    avatar_url VARCHAR(500),
    description VARCHAR(500),
    created_by UUID NOT NULL,
    status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'ARCHIVED', 'DISABLED')),
    join_mode VARCHAR(20) DEFAULT 'INVITE_ONLY' CHECK (join_mode IN ('OPEN', 'APPROVAL', 'INVITE_ONLY')),
    member_limit INT DEFAULT 1000,
    invite_link VARCHAR(100) UNIQUE,
    invite_link_expires_at TIMESTAMPTZ,
    is_encrypted BOOLEAN DEFAULT FALSE,
    allow_member_invite BOOLEAN DEFAULT TRUE,
    allow_member_pin BOOLEAN DEFAULT FALSE,
    allow_member_edit_info BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_conv_type ON conversation(type);
CREATE INDEX IF NOT EXISTS idx_conv_created_by ON conversation(created_by);

-- Conversation member table
CREATE TABLE IF NOT EXISTS conversation_member (
    conversation_id UUID NOT NULL REFERENCES conversation(conversation_id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    role VARCHAR(20) DEFAULT 'MEMBER' CHECK (role IN ('OWNER', 'ADMIN', 'MEMBER')),
    nickname VARCHAR(50),
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    joined_by UUID,
    left_at TIMESTAMPTZ,
    removed_by UUID,
    mute_until TIMESTAMPTZ,
    is_pinned BOOLEAN DEFAULT FALSE,
    pin_order INT,
    is_hidden BOOLEAN DEFAULT FALSE,
    last_read_seq BIGINT DEFAULT 0,
    last_read_at TIMESTAMPTZ,
    notification_setting VARCHAR(20) DEFAULT 'ALL' CHECK (notification_setting IN ('ALL', 'MENTIONS', 'NONE')),
    PRIMARY KEY (conversation_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_conv_member_user ON conversation_member(user_id) WHERE left_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_conv_member_conv ON conversation_member(conversation_id) WHERE left_at IS NULL;

-- Direct conversation map (for quick 1:1 lookup)
CREATE TABLE IF NOT EXISTS conversation_direct_map (
    user_id_1 UUID NOT NULL,
    user_id_2 UUID NOT NULL,
    conversation_id UUID NOT NULL REFERENCES conversation(conversation_id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id_1, user_id_2),
    CONSTRAINT ordered_direct_users CHECK (user_id_1 < user_id_2)
);

CREATE INDEX IF NOT EXISTS idx_direct_map_conv ON conversation_direct_map(conversation_id);

-- Message table
CREATE TABLE IF NOT EXISTS message (
    message_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES conversation(conversation_id),
    sender_id UUID NOT NULL,
    client_message_id UUID,
    message_type VARCHAR(30) DEFAULT 'TEXT' CHECK (message_type IN ('TEXT', 'IMAGE', 'VIDEO', 'FILE', 'AUDIO', 'STICKER', 'GIF', 'LOCATION', 'CONTACT', 'SYSTEM', 'REPLY', 'FORWARD')),
    content TEXT,
    reply_to_id UUID,
    forward_from_id UUID,
    server_seq BIGINT DEFAULT 0,
    status VARCHAR(20) DEFAULT 'SENT' CHECK (status IN ('SENDING', 'SENT', 'DELIVERED', 'READ', 'FAILED', 'DELETED', 'RECALLED')),
    is_pinned BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    recalled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_msg_conv_seq ON message(conversation_id, server_seq DESC);
CREATE INDEX IF NOT EXISTS idx_msg_sender ON message(sender_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_msg_client_id ON message(client_message_id) WHERE client_message_id IS NOT NULL;

-- Message read receipt table
CREATE TABLE IF NOT EXISTS message_read_receipt (
    message_id UUID NOT NULL REFERENCES message(message_id),
    user_id UUID NOT NULL,
    read_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (message_id, user_id)
);

-- Conversation inbox (CQRS read model for fast inbox listing)
CREATE TABLE IF NOT EXISTS conversation_inbox (
    user_id UUID NOT NULL,
    conversation_id UUID NOT NULL REFERENCES conversation(conversation_id),
    last_message_seq BIGINT DEFAULT 0,
    last_message_at TIMESTAMPTZ,
    last_message_preview VARCHAR(200),
    last_message_sender_id UUID,
    last_message_type VARCHAR(30),
    unread_count INT DEFAULT 0,
    is_pinned BOOLEAN DEFAULT FALSE,
    is_muted BOOLEAN DEFAULT FALSE,
    is_hidden BOOLEAN DEFAULT FALSE,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, conversation_id)
);

CREATE INDEX IF NOT EXISTS idx_inbox_user_sort ON conversation_inbox(user_id, is_pinned DESC, last_message_seq DESC);
CREATE INDEX IF NOT EXISTS idx_inbox_unread ON conversation_inbox(user_id) WHERE unread_count > 0;
