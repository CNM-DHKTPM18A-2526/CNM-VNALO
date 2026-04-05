package iuh.cnm.vnalo.content_service.model.dto;

import lombok.Builder;
import lombok.Getter;

import java.time.OffsetDateTime;
import java.util.UUID;

@Getter
@Builder
public class CommentResponse {

    private UUID commentId;
    private UUID postId;
    private UUID authorId;
    private UUID parentCommentId;
    private String contentText;
    private Integer likeCount;
    private String status;
    private OffsetDateTime createdAt;
    private OffsetDateTime updatedAt;
}