package iuh.cnm.vnalo.content_service.model.entity;

import jakarta.persistence.*;
import lombok.*;

import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
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

    @Builder.Default
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "included_ids", columnDefinition = "jsonb")
    private List<String> includedIds = new ArrayList<>();

    @Builder.Default
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "excluded_ids", columnDefinition = "jsonb")
    private List<String> excludedIds = new ArrayList<>();
}