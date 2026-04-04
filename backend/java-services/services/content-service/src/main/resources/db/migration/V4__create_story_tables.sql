CREATE TABLE content.story (
    story_id UUID PRIMARY KEY,
    author_id UUID NOT NULL,

    media_url TEXT NOT NULL,
    caption TEXT,

    visibility VARCHAR(20) DEFAULT 'PUBLIC',

    status VARCHAR(20) DEFAULT 'ACTIVE',

    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE INDEX idx_story_author
ON content.story(author_id);

CREATE INDEX idx_story_expires
ON content.story(expires_at);


CREATE TABLE content.story_view (
    view_id UUID PRIMARY KEY,
    story_id UUID NOT NULL,
    viewer_id UUID NOT NULL,

    viewed_at TIMESTAMP WITH TIME ZONE DEFAULT now(),

    CONSTRAINT fk_story_view_story
        FOREIGN KEY (story_id)
        REFERENCES content.story(story_id)
);

CREATE INDEX idx_story_view_story
ON content.story_view(story_id);