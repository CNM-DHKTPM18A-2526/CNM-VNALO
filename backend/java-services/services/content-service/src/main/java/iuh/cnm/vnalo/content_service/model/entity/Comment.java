package iuh.cnm.vnalo.content_service.model.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.UUID;

@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "comment", schema = "content")
public class Comment extends BaseAuditEntity {

    @Id
    @Column(name = "comment_id", nullable = false, updatable = false)
    private UUID commentId;

    @Column(name = "post_id", nullable = false)
    private UUID postId;

    @Column(name = "author_id", nullable = false)
    private UUID authorId;

    @Column(name = "parent_comment_id")
    private UUID parentCommentId;

    @Column(name = "content_text", nullable = false, columnDefinition = "text")
    private String contentText;

    @Builder.Default
    @Column(name = "like_count", nullable = false)
    private Integer likeCount = 0;

    @Builder.Default
    @Column(name = "status", nullable = false, length = 20)
    private String status = "ACTIVE";

    @PrePersist
    public void prePersist() {
        if (commentId == null) {
            commentId = UUID.randomUUID();
        }
        if (likeCount == null) {
            likeCount = 0;
        }
        if (status == null || status.isBlank()) {
            status = "ACTIVE";
        }
    }
}