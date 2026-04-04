-- V2: Add Appeal Table
-- Adds moderation_appeal table for user appeals against moderation decisions

CREATE TABLE IF NOT EXISTS moderation_appeal (
    appeal_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id UUID NOT NULL,
    user_id UUID NOT NULL,
    reason VARCHAR(1000) NOT NULL,
    status VARCHAR(20) NOT NULL,
    moderator_response VARCHAR(1000),
    moderator_id UUID,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Foreign key constraints
ALTER TABLE moderation_appeal
ADD CONSTRAINT fk_appeal_case
FOREIGN KEY (case_id) REFERENCES moderation_case(case_id);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_appeal_case ON moderation_appeal(case_id);
CREATE INDEX IF NOT EXISTS idx_appeal_user ON moderation_appeal(user_id);
CREATE INDEX IF NOT EXISTS idx_appeal_status ON moderation_appeal(status);