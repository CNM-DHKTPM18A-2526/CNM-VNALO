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
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "post", schema = "content")
public class Post extends BaseAuditEntity {

    @Id
    @Column(name = "post_id", nullable = false, updatable = false)
    private UUID postId;

    @Column(name = "author_id", nullable = false)
    private UUID authorId;

    @Column(name = "content_text", columnDefinition = "text")
    private String contentText;

    /**
     * Lưu dạng JSONB trong PostgreSQL.
     * Ví dụ:
     * ["https://cdn.vnalo.com/a.jpg", "https://cdn.vnalo.com/b.mp4"]
     */
    @Builder.Default
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "media_urls", nullable = false, columnDefinition = "jsonb")
    private List<String> mediaUrls = new ArrayList<>();

    @Builder.Default
    @Column(name = "visibility", nullable = false, length = 20)
    private String visibility = "PUBLIC";

    @Builder.Default
    @Column(name = "like_count", nullable = false)
    private Integer likeCount = 0;

    @Builder.Default
    @Column(name = "comment_count", nullable = false)
    private Integer commentCount = 0;

    @Builder.Default
    @Column(name = "share_count", nullable = false)
    private Integer shareCount = 0;

    @Builder.Default
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "included_ids", columnDefinition = "jsonb")
    private List<String> includedIds = new ArrayList<>();

    @Builder.Default
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "excluded_ids", columnDefinition = "jsonb")
    private List<String> excludedIds = new ArrayList<>();

    @Builder.Default
    @Column(name = "status", nullable = false, length = 20)
    private String status = "ACTIVE";

    @PrePersist
    public void prePersist() {
        if (postId == null) {
            postId = UUID.randomUUID();
        }
        if (mediaUrls == null) {
            mediaUrls = new ArrayList<>();
        }
        if (visibility == null || visibility.isBlank()) {
            visibility = "PUBLIC";
        }
        if (includedIds == null) {
            includedIds = new ArrayList<>();
        }
        if (excludedIds == null) {
            excludedIds = new ArrayList<>();
        }
        if (status == null || status.isBlank()) {
            status = "ACTIVE";
        }
        if (likeCount == null) {
            likeCount = 0;
        }
        if (commentCount == null) {
            commentCount = 0;
        }
        if (shareCount == null) {
            shareCount = 0;
        }
    }
}