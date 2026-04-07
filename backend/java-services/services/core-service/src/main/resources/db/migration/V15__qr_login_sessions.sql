-- V15: Add QR login sessions for web login approval flow

CREATE TABLE IF NOT EXISTS auth_qr_login_session (
    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    qr_token VARCHAR(128) NOT NULL UNIQUE,
    status VARCHAR(20) NOT NULL,
    web_device_name VARCHAR(100),
    web_platform VARCHAR(20),
    web_ip_address VARCHAR(45),
    web_user_agent TEXT,
    web_location VARCHAR(255),
    mobile_device_id VARCHAR(100),
    mobile_device_name VARCHAR(100),
    mobile_platform VARCHAR(20),
    mobile_ip_address VARCHAR(45),
    mobile_location VARCHAR(255),
    approved_by_account_id UUID,
    available_at TIMESTAMP WITH TIME ZONE NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    approved_at TIMESTAMP WITH TIME ZONE,
    consumed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_qr_login_token ON auth_qr_login_session(qr_token);
CREATE INDEX IF NOT EXISTS idx_qr_login_expires ON auth_qr_login_session(expires_at);
CREATE INDEX IF NOT EXISTS idx_qr_login_status ON auth_qr_login_session(status);
