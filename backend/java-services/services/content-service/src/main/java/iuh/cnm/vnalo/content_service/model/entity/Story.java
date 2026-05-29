package iuh.cnm.vnalo.content_service.model.entity;

import jakarta.persistence.*;
import lombok.*;

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
    private UUID storyId;

    private UUID authorId;

    private String mediaUrl;

    private String caption;

    private String visibility;

    private String status;

    private OffsetDateTime expiresAt;
}