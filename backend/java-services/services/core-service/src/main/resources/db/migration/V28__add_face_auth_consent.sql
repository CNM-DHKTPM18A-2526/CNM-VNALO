-- Add consent tracking to face_enrollments
ALTER TABLE face_enrollments 
ADD COLUMN IF NOT EXISTS terms_version VARCHAR(50),
ADD COLUMN IF NOT EXISTS consent_agreed BOOLEAN DEFAULT FALSE;

-- If existing records exist, we set them to true and version 1.0 since they were enrolled before this tracking
UPDATE face_enrollments SET consent_agreed = TRUE, terms_version = '1.0' WHERE consent_agreed IS FALSE OR consent_agreed IS NULL;

-- Clear existing embeddings because we are changing the encryption key derivation algorithm from SHA-256 to PBKDF2
-- Old encrypted embeddings will no longer be decipherable
UPDATE face_enrollments SET is_active = FALSE;
