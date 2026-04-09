CREATE TABLE IF NOT EXISTS auth_session_audit (
    audit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL,
    token_id UUID,
    event_type VARCHAR(80) NOT NULL,
    session_type VARCHAR(40),
    trust_level VARCHAR(40),
    platform VARCHAR(20),
    device_id VARCHAR(100),
    device_name VARCHAR(100),
    ip_address VARCHAR(45),
    detail VARCHAR(500),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_auth_session_audit_account
    ON auth_session_audit(account_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_auth_session_audit_event
    ON auth_session_audit(event_type, created_at DESC);
