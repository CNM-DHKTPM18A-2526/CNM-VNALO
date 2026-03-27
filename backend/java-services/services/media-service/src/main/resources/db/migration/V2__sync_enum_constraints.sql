-- Sync CHECK constraints with Java enums

-- 1. media_category: remove STICKER (moved to sticker-service), keep all others
ALTER TABLE media_object DROP CONSTRAINT IF EXISTS media_object_media_category_check;
ALTER TABLE media_object ADD CONSTRAINT media_object_media_category_check
    CHECK (media_category IN (
        'AVATAR', 'COVER', 'CHAT_IMAGE', 'CHAT_VIDEO', 'CHAT_FILE',
        'CHAT_VOICE', 'STORY', 'TIMELINE'
    ));

-- 2. status: add PRE_UPLOAD (used for presigned upload flow)
ALTER TABLE media_object DROP CONSTRAINT IF EXISTS media_object_status_check;
ALTER TABLE media_object ADD CONSTRAINT media_object_status_check
    CHECK (status IN ('PRE_UPLOAD', 'UPLOADING', 'PROCESSING', 'READY', 'FAILED', 'DELETED'));
