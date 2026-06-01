package iuh.cnm.vnalo.content_service.model.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "story", schema = "content")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Story extends BaseAuditEntity {

    @Id
    @GeneratedValue
    @Column(name = "story_id", nullable = false, updatable = false)
    private UUID storyId;

    @Column(name = "author_id", nullable = false)
    private UUID authorId;

    @Column(name = "media_url", nullable = false)
    private String mediaUrl;

    @Column(name = "caption")
    private String caption;

    @Column(name = "visibility")
    private String visibility;

    @Column(name = "status")
    private String status;

    @Column(name = "expires_at", nullable = false)
    private OffsetDateTime expiresAt;
}
