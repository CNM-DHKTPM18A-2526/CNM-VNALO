-- V1: Init Moderation Schema
-- Creates all moderation-related tables

-- Moderation Report Table
CREATE TABLE IF NOT EXISTS moderation_report (
    report_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_user_id UUID NOT NULL,
    target_type VARCHAR(20) NOT NULL,
    target_id UUID NOT NULL,
    reason_code VARCHAR(50) NOT NULL,
    description VARCHAR(1000),
    status VARCHAR(20) NOT NULL,
    priority VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Moderation Report Evidence Table
CREATE TABLE IF NOT EXISTS moderation_report_evidence (
    evidence_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id UUID NOT NULL,
    snapshot_json JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Moderation Case Table
CREATE TABLE IF NOT EXISTS moderation_case (
    case_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id UUID NOT NULL UNIQUE,
    assigned_moderator_id UUID,
    status VARCHAR(20) NOT NULL,
    decision VARCHAR(30) NOT NULL,
    note VARCHAR(1000),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    resolved_at TIMESTAMPTZ
);

-- Moderation Action Table
CREATE TABLE IF NOT EXISTS moderation_action (
    action_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id UUID NOT NULL,
    action_type VARCHAR(40) NOT NULL,
    target_user_id UUID,
    target_message_id UUID,
    target_conversation_id UUID,
    reason VARCHAR(1000),
    created_by UUID NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Moderation Audit Log Table
CREATE TABLE IF NOT EXISTS moderation_audit_log (
    audit_log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id UUID,
    case_id UUID,
    action VARCHAR(50) NOT NULL,
    old_value_json JSONB,
    new_value_json JSONB,
    performed_by UUID NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Moderation Admin User Table
CREATE TABLE IF NOT EXISTS moderation_admin_user (
    user_id UUID PRIMARY KEY,
    role VARCHAR(20) NOT NULL,
    is_active BOOLEAN NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_report_reporter ON moderation_report(reporter_user_id);
CREATE INDEX IF NOT EXISTS idx_report_target ON moderation_report(target_type, target_id);
CREATE INDEX IF NOT EXISTS idx_report_status ON moderation_report(status);
CREATE INDEX IF NOT EXISTS idx_evidence_report ON moderation_report_evidence(report_id);
CREATE INDEX IF NOT EXISTS idx_case_report ON moderation_case(report_id);
CREATE INDEX IF NOT EXISTS idx_case_moderator ON moderation_case(assigned_moderator_id);
CREATE INDEX IF NOT EXISTS idx_action_case ON moderation_action(case_id);
CREATE INDEX IF NOT EXISTS idx_audit_report ON moderation_audit_log(report_id);
CREATE INDEX IF NOT EXISTS idx_audit_case ON moderation_audit_log(case_id);