-- ============================================================
-- V23: Align Member Roles with v5.0 Standards
-- Renames: OWNER -> ADMIN (Leader)
-- Renames: ADMIN -> DEPUTY (Sub-leader)
-- ============================================================

-- 1. Drop the old check constraint
ALTER TABLE conversation_member DROP CONSTRAINT IF EXISTS conversation_member_role_check;

-- 2. Update existing data to new role names
-- CAUTION: Order matters to avoid collision if there's no intermediate state
-- We use temporary markers if necessary, but here we can use CASE
UPDATE conversation_member 
SET role = CASE 
    WHEN role = 'OWNER' THEN 'ADMIN'
    WHEN role = 'ADMIN' THEN 'DEPUTY'
    ELSE role 
END;

-- 3. Re-add the check constraint with new allowed values
ALTER TABLE conversation_member ADD CONSTRAINT conversation_member_role_check 
CHECK (role IN ('ADMIN', 'DEPUTY', 'MEMBER'));

-- 4. Update default value for future records
ALTER TABLE conversation_member ALTER COLUMN role SET DEFAULT 'MEMBER';
