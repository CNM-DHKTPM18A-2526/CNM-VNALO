-- V13: Group join approval queue + default OPEN join mode
-- 1) Introduce pending join requests for APPROVAL mode
-- 2) Change join_mode default to OPEN (Zalo-like default behavior)

CREATE TABLE IF NOT EXISTS conversation_join_request (
    conversation_id UUID NOT NULL REFERENCES conversation(conversation_id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    requested_by UUID NOT NULL,
    requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (conversation_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_conv_join_request_conversation
    ON conversation_join_request(conversation_id);

CREATE INDEX IF NOT EXISTS idx_conv_join_request_requested_by
    ON conversation_join_request(requested_by);

ALTER TABLE conversation
    ALTER COLUMN join_mode SET DEFAULT 'OPEN';
