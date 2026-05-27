package iuh.cnm.vnalo.content_service.model.dto;

import lombok.Builder;
import lombok.Getter;

import java.time.OffsetDateTime;
import java.util.UUID;

@Getter
@Builder
public class StoryReactionResponse {

    private UUID storyReactionId;
    private UUID storyId;
    private UUID userId;
    private String reactionType;
    private OffsetDateTime createdAt;
}
