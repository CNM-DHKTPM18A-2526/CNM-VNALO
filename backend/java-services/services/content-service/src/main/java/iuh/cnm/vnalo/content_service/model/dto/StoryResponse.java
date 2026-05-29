package iuh.cnm.vnalo.content_service.model.dto;

import lombok.Builder;
import lombok.Getter;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@Getter
@Builder
public class StoryResponse {

    private UUID storyId;

    private UUID authorId;

    private String mediaUrl;

    private String caption;

    private String visibility;

    private List<String> includedIds;

    private List<String> excludedIds;

    private OffsetDateTime expiresAt;

    private OffsetDateTime createdAt;
}