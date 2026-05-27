ALTER TABLE content.post
ADD COLUMN IF NOT EXISTS included_ids jsonb DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS excluded_ids jsonb DEFAULT '[]'::jsonb;
