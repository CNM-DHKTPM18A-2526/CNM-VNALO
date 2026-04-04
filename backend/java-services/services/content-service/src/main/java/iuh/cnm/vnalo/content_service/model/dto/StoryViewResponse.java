package iuh.cnm.vnalo.content_service.model.dto;

import lombok.Builder;
import lombok.Getter;

import java.time.OffsetDateTime;
import java.util.UUID;

@Getter
@Builder
public class StoryViewResponse {

    private UUID viewId;
    private UUID storyId;
    private UUID viewerId;
    private OffsetDateTime viewedAt;
}