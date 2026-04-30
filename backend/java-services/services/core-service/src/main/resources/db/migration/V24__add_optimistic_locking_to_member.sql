-- V24: Add optimistic locking column to conversation_member
-- This supports the hardened message-service architecture
-- Migration Date: 2026-04-29

ALTER TABLE conversation_member ADD COLUMN IF NOT EXISTS version INTEGER DEFAULT 0;
