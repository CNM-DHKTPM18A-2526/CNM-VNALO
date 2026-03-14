-- ============================================================
-- V10: Schema Hardening and Alignment
-- Purpose:
--   1) Keep migration history immutable (do not edit V1-V9)
--   2) Add idempotent guards for previously fragile operations
--   3) Align DB constraints/indexes with runtime entity expectations
-- ============================================================

-- ------------------------------------------------------------
-- 1) Repair legacy message columns if DB was created outside Flyway
-- ------------------------------------------------------------
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'message'
          AND column_name = 'reply_to_id'
    ) AND NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'message'
          AND column_name = 'reply_to_message_id'
    ) THEN
        ALTER TABLE message RENAME COLUMN reply_to_id TO reply_to_message_id;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'message'
          AND column_name = 'forward_from_id'
    ) AND NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'message'
          AND column_name = 'forward_from_message_id'
    ) THEN
        ALTER TABLE message RENAME COLUMN forward_from_id TO forward_from_message_id;
    END IF;
END $$;

-- ------------------------------------------------------------
-- 2) Ensure essential foreign keys from V7 exist (idempotent)
-- ------------------------------------------------------------
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'user_setting')
       AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'user_profile')
       AND NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_setting_profile') THEN
        ALTER TABLE user_setting
            ADD CONSTRAINT fk_setting_profile
            FOREIGN KEY (user_id) REFERENCES user_profile(id) ON DELETE CASCADE;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'contact_sync')
       AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'user_profile')
       AND NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_contact_user') THEN
        ALTER TABLE contact_sync
            ADD CONSTRAINT fk_contact_user
            FOREIGN KEY (user_id) REFERENCES user_profile(id) ON DELETE CASCADE;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'contact_sync')
       AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'user_profile')
       AND NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_contact_matched') THEN
        ALTER TABLE contact_sync
            ADD CONSTRAINT fk_contact_matched
            FOREIGN KEY (matched_user_id) REFERENCES user_profile(id) ON DELETE SET NULL;
    END IF;
END $$;

-- ------------------------------------------------------------
-- 3) Enforce message uniqueness constraints expected by entities
-- ------------------------------------------------------------
DO $$
DECLARE
    has_dup_conv_seq BOOLEAN;
    has_dup_sender_client BOOLEAN;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_msg_conv_seq') THEN
        SELECT EXISTS (
            SELECT 1
            FROM (
                SELECT conversation_id, server_seq
                FROM message
                GROUP BY conversation_id, server_seq
                HAVING COUNT(*) > 1
            ) d
        ) INTO has_dup_conv_seq;

        IF NOT has_dup_conv_seq THEN
            ALTER TABLE message
                ADD CONSTRAINT uq_msg_conv_seq UNIQUE (conversation_id, server_seq);
        ELSE
            RAISE WARNING 'Skipped uq_msg_conv_seq because duplicate (conversation_id, server_seq) rows exist';
        END IF;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_msg_sender_client_id') THEN
        SELECT EXISTS (
            SELECT 1
            FROM (
                SELECT sender_id, client_message_id
                FROM message
                WHERE client_message_id IS NOT NULL
                GROUP BY sender_id, client_message_id
                HAVING COUNT(*) > 1
            ) d
        ) INTO has_dup_sender_client;

        IF NOT has_dup_sender_client THEN
            ALTER TABLE message
                ADD CONSTRAINT uq_msg_sender_client_id UNIQUE (sender_id, client_message_id);
        ELSE
            RAISE WARNING 'Skipped uq_msg_sender_client_id because duplicate (sender_id, client_message_id) rows exist';
        END IF;
    END IF;
END $$;

-- ------------------------------------------------------------
-- 4) Ensure important performance indexes are present
-- ------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_conv_invite_link
    ON conversation(invite_link)
    WHERE invite_link IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_refresh_token_expires
    ON auth_refresh_token(account_id, expires_at);

CREATE INDEX IF NOT EXISTS idx_receipt_user
    ON message_receipt(user_id, seen_at);

-- ------------------------------------------------------------
-- 5) Ensure relation integrity for messaging read models
-- ------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_inbox_user_profile') THEN
        ALTER TABLE conversation_inbox
            ADD CONSTRAINT fk_inbox_user_profile
            FOREIGN KEY (user_id) REFERENCES user_profile(id) ON DELETE CASCADE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_conv_member_user_profile') THEN
        ALTER TABLE conversation_member
            ADD CONSTRAINT fk_conv_member_user_profile
            FOREIGN KEY (user_id) REFERENCES user_profile(id) ON DELETE CASCADE;
    END IF;
END $$;
