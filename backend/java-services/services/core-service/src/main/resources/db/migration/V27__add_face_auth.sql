-- V27: Add face authentication tables
-- Migration Date: 2026-05-23
-- Tables for face enrollment (encrypted embeddings) and verification audit logs

-- Table to store user face enrollments with encrypted embeddings
CREATE TABLE IF NOT EXISTS face_enrollments (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID NOT NULL,
    embedding_data TEXT NOT NULL,
    enrolled_at     TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    version         INTEGER NOT NULL DEFAULT 1,
    liveness_score DECIMAL(5,4),
    quality_score   DECIMAL(5,4),
    device_info     JSONB,
    CONSTRAINT fk_face_enrollment_user
        FOREIGN KEY (user_id) REFERENCES auth_account(id) ON DELETE CASCADE
);

-- Table to store face verification audit logs
CREATE TABLE IF NOT EXISTS face_verification_logs (
    id                  BIGSERIAL PRIMARY KEY,
    user_id             UUID NOT NULL,
    verified            BOOLEAN NOT NULL,
    confidence          DECIMAL(5,4),
    liveness_score     DECIMAL(5,4),
    threshold           DECIMAL(5,4) DEFAULT 0.65,
    ip_address         VARCHAR(45),
    device_id          VARCHAR(255),
    app_version        VARCHAR(50),
    inference_time_ms   INTEGER,
    created_at         TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_face_verify_log_user
        FOREIGN KEY (user_id) REFERENCES auth_account(id) ON DELETE CASCADE
);

-- Indexes for face_enrollments
CREATE INDEX IF NOT EXISTS idx_face_enrollment_user ON face_enrollments(user_id);
CREATE INDEX IF NOT EXISTS idx_face_enrollment_active ON face_enrollments(is_active) WHERE is_active = TRUE;

-- Indexes for face_verification_logs
CREATE INDEX IF NOT EXISTS idx_face_verify_log_user ON face_verification_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_face_verify_log_created ON face_verification_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_face_verify_log_verified ON face_verification_logs(verified);
