-- Change table name if needed or just add column
ALTER TABLE content.post_like ADD COLUMN reaction_type VARCHAR(20) DEFAULT 'LOVE';

-- We could rename post_like to post_reaction in the future, but for now just adding the column is backwards compatible.
