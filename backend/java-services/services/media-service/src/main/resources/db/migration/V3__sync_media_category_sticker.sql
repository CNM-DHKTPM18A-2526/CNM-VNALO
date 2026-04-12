-- V3: Update media_category constraint to include STICKER, EMOJI, and GIF
ALTER TABLE media_object DROP CONSTRAINT IF EXISTS media_object_media_category_check;
ALTER TABLE media_object ADD CONSTRAINT media_object_media_category_check
    CHECK (media_category IN (
        'AVATAR', 'COVER', 'CHAT_IMAGE', 'CHAT_VIDEO', 'CHAT_FILE',
        'CHAT_VOICE', 'STORY', 'TIMELINE', 'STICKER', 'EMOJI', 'GIF'
    ));
