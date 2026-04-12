-- V4: Add GIF and EMOJI to media_category check constraint
ALTER TABLE media_metadata DROP CONSTRAINT IF EXISTS media_metadata_media_category_check;

ALTER TABLE media_metadata ADD CONSTRAINT media_metadata_media_category_check 
CHECK (media_category = ANY (ARRAY[
    'AVATAR'::text, 
    'COVER'::text, 
    'CHAT_IMAGE'::text, 
    'CHAT_VIDEO'::text, 
    'CHAT_FILE'::text, 
    'CHAT_VOICE'::text, 
    'STORY'::text, 
    'TIMELINE'::text, 
    'STICKER'::text, 
    'EMOJI'::text, 
    'GIF'::text
]));
