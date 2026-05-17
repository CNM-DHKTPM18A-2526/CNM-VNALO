-- V26: Add stable client entry id for idempotent AI history sync

ALTER TABLE ai_chat_history
    ADD COLUMN IF NOT EXISTS client_entry_id VARCHAR(100);

CREATE UNIQUE INDEX IF NOT EXISTS ux_ai_history_client_entry
    ON ai_chat_history(user_id, conversation_id, client_entry_id)
    WHERE client_entry_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_ai_history_created_at
    ON ai_chat_history(user_id, conversation_id, created_at);
