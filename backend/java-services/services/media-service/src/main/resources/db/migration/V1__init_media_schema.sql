CREATE TABLE media_object (
    media_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL,
    bucket VARCHAR(50) NOT NULL,
    object_key VARCHAR(500) NOT NULL,
    url VARCHAR(500),
    thumbnail_url VARCHAR(500),
    mime_type VARCHAR(100) NOT NULL,
    size_bytes BIGINT NOT NULL,
    checksum VARCHAR(64),
    width INT,
    height INT,
    duration_ms INT,
    original_filename VARCHAR(255),
    media_category VARCHAR(30) CHECK (media_category IN (
        'AVATAR', 'COVER', 'CHAT_IMAGE', 'CHAT_VIDEO', 'CHAT_FILE', 
        'CHAT_VOICE', 'STORY', 'TIMELINE', 'STICKER'
    )),
    status VARCHAR(20) DEFAULT 'UPLOADING' CHECK (status IN ('UPLOADING', 'PROCESSING', 'READY', 'FAILED', 'DELETED')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_media_owner ON media_object(owner_user_id, created_at DESC);
CREATE INDEX idx_media_status ON media_object(status);
CREATE INDEX idx_media_category ON media_object(media_category, created_at DESC);

CREATE TABLE media_access_scope (
    media_id UUID NOT NULL,
    scope_type VARCHAR(20) NOT NULL CHECK (scope_type IN ('CONVERSATION', 'USER', 'PUBLIC')),
    scope_id UUID NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (media_id, scope_type, scope_id)
);
