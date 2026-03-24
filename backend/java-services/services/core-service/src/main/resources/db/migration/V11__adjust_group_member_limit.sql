-- ============================================================
-- V11: Adjust group member limit default from 1000 to 100
-- Business rule: Standard groups limited to 100 members
-- Future: Community groups (paid upgrade) can have higher limits
-- ============================================================

-- Change default for new conversations
ALTER TABLE conversation ALTER COLUMN member_limit SET DEFAULT 100;

-- Update existing groups that still have the old default of 1000
-- (only if they haven't been explicitly set to a custom value)
UPDATE conversation
SET member_limit = 100
WHERE member_limit = 1000
  AND type = 'GROUP';
