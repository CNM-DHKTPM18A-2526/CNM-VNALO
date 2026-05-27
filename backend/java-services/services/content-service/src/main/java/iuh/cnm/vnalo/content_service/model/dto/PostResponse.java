package iuh.cnm.vnalo.content_service.model.dto;

import lombok.Builder;
import lombok.Getter;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@Getter
@Builder
public class PostResponse {

    private UUID postId;
    private UUID authorId;
    private String contentText;
    private List<String> mediaUrls;
    private String visibility;
    private List<String> includedIds;
    private List<String> excludedIds;
    private Integer likeCount;
    private Integer commentCount;
    private Integer shareCount;
    private String status;
    private OffsetDateTime createdAt;
    private OffsetDateTime updatedAt;
}