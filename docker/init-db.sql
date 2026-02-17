-- =============================================================================
-- VNALO — Database Initialization
-- Both core-service (Flyway) and message-service (TypeORM) use the 'public'
-- schema. No custom schemas are needed.
-- =============================================================================

-- Ensure UUID extension is available (used by both services)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Default search path
ALTER DATABASE vnalo_core SET search_path TO public;
