package iuh.cnm.vnalo.mediaservice.domain.model;

public enum MediaCategory {
    AVATAR,
    COVER,
    CHAT_IMAGE,
    CHAT_VIDEO,
    CHAT_FILE,
    CHAT_VOICE,
    STORY,
    TIMELINE,
    STICKER,
    EMOJI,
    GIF;

    public boolean isImage() {
        return this == AVATAR || this == COVER || this == CHAT_IMAGE || this == STORY || this == TIMELINE || this == STICKER || this == EMOJI || this == GIF;
    }

    public boolean isVideo() {
        return this == CHAT_VIDEO;
    }
}
