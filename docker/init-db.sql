-- =============================================================================
-- VNALO — Full Database Initialization Script
-- This script creates all necessary databases for the microservices architecture.
-- =============================================================================

-- 1. Create Core Database (Used by core-service and message-service)
SELECT 'CREATE DATABASE vnalo_core' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'vnalo_core')\gexec

-- 2. Create Media Database
SELECT 'CREATE DATABASE vnalo_media' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'vnalo_media')\gexec

-- 3. Create AI Assistant Database
SELECT 'CREATE DATABASE vnalo_ai' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'vnalo_ai')\gexec

-- 4. Create Analytics Database
SELECT 'CREATE DATABASE vnalo_analytics' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'vnalo_analytics')\gexec

-- 5. Create Notification Database
SELECT 'CREATE DATABASE vnalo_notification' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'vnalo_notification')\gexec

-- 6. Create Moderation Database
SELECT 'CREATE DATABASE vnalo_moderation' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'vnalo_moderation')\gexec

-- 7. Create Content Database
SELECT 'CREATE DATABASE vnalo_content' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'vnalo_content')\gexec

-- =============================================================================
-- Basic Extensions and Search Paths Configuration
-- Note: Extensions must be enabled on each database individually
-- =============================================================================

\c vnalo_core
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
ALTER DATABASE vnalo_core SET search_path TO public;

\c vnalo_media
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
ALTER DATABASE vnalo_media SET search_path TO public;

\c vnalo_ai
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
ALTER DATABASE vnalo_ai SET search_path TO public;

\c vnalo_analytics
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
ALTER DATABASE vnalo_analytics SET search_path TO public;

\c vnalo_notification
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
ALTER DATABASE vnalo_notification SET search_path TO public;

\c vnalo_moderation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
ALTER DATABASE vnalo_moderation SET search_path TO public;

\c vnalo_content
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
ALTER DATABASE vnalo_content SET search_path TO public;
