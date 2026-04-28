-- ============================================================
-- V21: Add Group Settings Columns
-- Adds missing administrative and permission columns to conversation table
-- Adds nickname column to conversation_member table
-- ============================================================

-- Add new settings columns to conversation
ALTER TABLE conversation ADD COLUMN IF NOT EXISTS only_admin_can_post BOOLEAN DEFAULT FALSE;
ALTER TABLE conversation ADD COLUMN IF NOT EXISTS highlight_admin_messages BOOLEAN DEFAULT TRUE;
ALTER TABLE conversation ADD COLUMN IF NOT EXISTS show_history_to_new_members BOOLEAN DEFAULT TRUE;
ALTER TABLE conversation ADD COLUMN IF NOT EXISTS allow_member_create_note BOOLEAN DEFAULT TRUE;
ALTER TABLE conversation ADD COLUMN IF NOT EXISTS allow_member_create_poll BOOLEAN DEFAULT TRUE;

-- Add nickname to conversation_member
ALTER TABLE conversation_member ADD COLUMN IF NOT EXISTS nickname VARCHAR(50);
