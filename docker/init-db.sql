-- Create schemas for each service
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS users;
CREATE SCHEMA IF NOT EXISTS social;
CREATE SCHEMA IF NOT EXISTS messaging;
CREATE SCHEMA IF NOT EXISTS media;
CREATE SCHEMA IF NOT EXISTS content;
CREATE SCHEMA IF NOT EXISTS moderation;
CREATE SCHEMA IF NOT EXISTS analytics;

-- Grant permissions
GRANT ALL PRIVILEGES ON SCHEMA auth TO postgres;
GRANT ALL PRIVILEGES ON SCHEMA users TO postgres;
GRANT ALL PRIVILEGES ON SCHEMA social TO postgres;
GRANT ALL PRIVILEGES ON SCHEMA messaging TO postgres;
GRANT ALL PRIVILEGES ON SCHEMA media TO postgres;
GRANT ALL PRIVILEGES ON SCHEMA content TO postgres;
GRANT ALL PRIVILEGES ON SCHEMA moderation TO postgres;
GRANT ALL PRIVILEGES ON SCHEMA analytics TO postgres;

-- Set default schema search path
ALTER DATABASE vnalo_core SET search_path TO auth, users, social, messaging, media, content, moderation, analytics, public;
