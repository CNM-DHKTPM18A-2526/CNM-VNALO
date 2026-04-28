-- ============================================================
-- V22: Align Legacy Group Settings
-- Updates default values for columns created in V8 to match v5.0 standards
-- ============================================================

-- 1. Update defaults for FUTURE records
ALTER TABLE conversation ALTER COLUMN allow_member_pin SET DEFAULT TRUE;
ALTER TABLE conversation ALTER COLUMN allow_member_edit_info SET DEFAULT TRUE;

-- 2. Update EXISTING records to enable these features by default (UX Alignment)
UPDATE conversation SET allow_member_pin = TRUE WHERE allow_member_pin IS FALSE;
UPDATE conversation SET allow_member_edit_info = TRUE WHERE allow_member_edit_info IS FALSE;
