-- Add privacy fields for post
ALTER TABLE content.post ADD COLUMN IF NOT EXISTS included_ids jsonb DEFAULT '[]'::jsonb;
ALTER TABLE content.post ADD COLUMN IF NOT EXISTS excluded_ids jsonb DEFAULT '[]'::jsonb;

-- Add privacy fields for story
ALTER TABLE content.story ADD COLUMN IF NOT EXISTS included_ids jsonb DEFAULT '[]'::jsonb;
ALTER TABLE content.story ADD COLUMN IF NOT EXISTS excluded_ids jsonb DEFAULT '[]'::jsonb;
