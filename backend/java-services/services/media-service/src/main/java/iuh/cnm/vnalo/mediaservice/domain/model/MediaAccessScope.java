package iuh.cnm.vnalo.mediaservice.domain.model;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.io.Serializable;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "media_access_scope")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@IdClass(MediaAccessScope.MediaAccessScopeId.class)
public class MediaAccessScope {

    @Id
    @Column(name = "media_id")
    private UUID mediaId;

    @Id
    @Enumerated(EnumType.STRING)
    @Column(name = "scope_type", length = 20)
    private ScopeType scopeType;

    @Id
    @Column(name = "scope_id")
    private UUID scopeId;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class MediaAccessScopeId implements Serializable {
        private UUID mediaId;
        private ScopeType scopeType;
        private UUID scopeId;
    }
}
