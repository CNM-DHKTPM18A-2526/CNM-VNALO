-- V14: Add account email for authentication/profile and align reset-password flow

ALTER TABLE auth_account
    ADD COLUMN IF NOT EXISTS email VARCHAR(255);

-- Case-insensitive uniqueness for email, while allowing existing null values.
CREATE UNIQUE INDEX IF NOT EXISTS uk_auth_account_email_lower
    ON auth_account (LOWER(email))
    WHERE email IS NOT NULL;

-- Helpful index for searching by email in auth flows.
CREATE INDEX IF NOT EXISTS idx_auth_account_email
    ON auth_account (email);
