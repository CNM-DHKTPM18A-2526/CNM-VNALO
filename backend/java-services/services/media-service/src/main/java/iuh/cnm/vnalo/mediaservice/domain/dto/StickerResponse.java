package iuh.cnm.vnalo.mediaservice.domain.dto;

import iuh.cnm.vnalo.mediaservice.domain.model.Sticker;
import iuh.cnm.vnalo.mediaservice.domain.model.StickerFileType;
import lombok.Builder;
import lombok.Data;

import java.util.List;
import java.util.UUID;

@Data
@Builder
public class StickerResponse {

    private UUID stickerId;
    private UUID packId;
    private String name;
    private String imageUrl;
    private String thumbnailUrl;
    private StickerFileType fileType;
    private List<String> keywords;
    private String emojiMatch;
    private Integer orderIndex;

    public static StickerResponse from(Sticker sticker) {
        return StickerResponse.builder()
                .stickerId(sticker.getStickerId())
                .packId(sticker.getPackId())
                .name(sticker.getName())
                .imageUrl(sticker.getImageUrl())
                .thumbnailUrl(sticker.getThumbnailUrl())
                .fileType(sticker.getFileType())
                .keywords(sticker.getKeywords())
                .emojiMatch(sticker.getEmojiMatch())
                .orderIndex(sticker.getOrderIndex())
                .build();
    }
}
