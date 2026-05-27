CREATE TABLE IF NOT EXISTS content.story_reaction (
    story_reaction_id UUID PRIMARY KEY,
    story_id UUID NOT NULL,
    user_id UUID NOT NULL,
    reaction_type VARCHAR(20) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),

    CONSTRAINT fk_story_reaction_story
        FOREIGN KEY (story_id)
        REFERENCES content.story(story_id)
        ON DELETE CASCADE,

    CONSTRAINT uq_story_reaction_story_user
        UNIQUE (story_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_story_reaction_story
ON content.story_reaction(story_id);

CREATE INDEX IF NOT EXISTS idx_story_reaction_created_at
ON content.story_reaction(created_at DESC);
