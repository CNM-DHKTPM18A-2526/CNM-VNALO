-- ============================================================
-- V9: Messaging Schema Alignment
-- Aligns V8 tables with message-service TypeORM entities
-- Adds message_reaction, pinned_message, message_receipt tables
-- ============================================================

-- =====================================================
-- 1. ALTER message table to match Message entity
-- =====================================================

-- Rename reply_to_id → reply_to_message_id
DO $$ 
BEGIN 
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='message' AND column_name='reply_to_id') THEN
    ALTER TABLE message RENAME COLUMN reply_to_id TO reply_to_message_id;
  END IF;
END $$;

-- Rename forward_from_id → forward_from_message_id
DO $$ 
BEGIN 
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='message' AND column_name='forward_from_id') THEN
    ALTER TABLE message RENAME COLUMN forward_from_id TO forward_from_message_id;
  END IF;
END $$;

-- Add media columns (denormalized for fast access)
ALTER TABLE message ADD COLUMN IF NOT EXISTS media_url VARCHAR(500);
ALTER TABLE message ADD COLUMN IF NOT EXISTS media_thumbnail_url VARCHAR(500);
ALTER TABLE message ADD COLUMN IF NOT EXISTS media_mime_type VARCHAR(100);
ALTER TABLE message ADD COLUMN IF NOT EXISTS media_size_bytes BIGINT;

-- Add reply denormalization fields
ALTER TABLE message ADD COLUMN IF NOT EXISTS reply_to_sender_id UUID;
ALTER TABLE message ADD COLUMN IF NOT EXISTS reply_to_content VARCHAR(200);

-- Add forward denormalization field
ALTER TABLE message ADD COLUMN IF NOT EXISTS forward_from_conversation_id UUID;

-- Add edit tracking
ALTER TABLE message ADD COLUMN IF NOT EXISTS is_edited BOOLEAN DEFAULT FALSE;
ALTER TABLE message ADD COLUMN IF NOT EXISTS edited_at TIMESTAMPTZ;

-- Note: V8 columns is_pinned, deleted_at, recalled_at are kept for backward compatibility

-- =====================================================
-- 2. Replace message_read_receipt with message_receipt
--    Entity uses 3-column PK with delivery tracking
-- =====================================================

DROP TABLE IF EXISTS message_read_receipt;

CREATE TABLE IF NOT EXISTS message_receipt (
    conversation_id UUID NOT NULL,
    message_id UUID NOT NULL REFERENCES message(message_id),
    user_id UUID NOT NULL,
    server_seq BIGINT NOT NULL,
    delivered_at TIMESTAMPTZ,
    seen_at TIMESTAMPTZ,
    PRIMARY KEY (conversation_id, message_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_receipt_user ON message_receipt(user_id, seen_at);

-- =====================================================
-- 3. Create message_reaction table
-- =====================================================

CREATE TABLE IF NOT EXISTS message_reaction (
    reaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL,
    message_id UUID NOT NULL REFERENCES message(message_id),
    server_seq BIGINT NOT NULL,
    user_id UUID NOT NULL,
    emoji VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_reaction UNIQUE (message_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_reaction_msg ON message_reaction(message_id);
CREATE INDEX IF NOT EXISTS idx_reaction_conv ON message_reaction(conversation_id, server_seq);

-- =====================================================
-- 4. Create pinned_message table
-- =====================================================

CREATE TABLE IF NOT EXISTS pinned_message (
    pin_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES conversation(conversation_id),
    message_id UUID NOT NULL REFERENCES message(message_id),
    server_seq BIGINT NOT NULL,
    pinned_by UUID NOT NULL,
    pinned_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_pin UNIQUE (conversation_id, message_id)
);

CREATE INDEX IF NOT EXISTS idx_pin_conv ON pinned_message(conversation_id, pinned_at);
