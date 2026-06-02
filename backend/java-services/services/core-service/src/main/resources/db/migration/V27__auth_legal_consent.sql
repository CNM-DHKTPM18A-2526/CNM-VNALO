CREATE TABLE IF NOT EXISTS auth_legal_consent (
    consent_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL,
    consent_type VARCHAR(40) NOT NULL,
    document_version VARCHAR(32) NOT NULL,
    granted BOOLEAN NOT NULL DEFAULT TRUE,
    granted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    ip_address VARCHAR(45),
    user_agent VARCHAR(500),
    device_name VARCHAR(100),
    platform VARCHAR(20),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE,
    CONSTRAINT fk_auth_legal_consent_account
        FOREIGN KEY (account_id) REFERENCES auth_account(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_auth_legal_consent_account
    ON auth_legal_consent(account_id, consent_type, granted_at DESC);

CREATE INDEX IF NOT EXISTS idx_auth_legal_consent_granted
    ON auth_legal_consent(granted_at DESC);