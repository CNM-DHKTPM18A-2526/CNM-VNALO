package iuh.cnm.vnalo.analytics_service.model.entity;

import iuh.cnm.vnalo.analytics_service.model.enums.AnalyticsEventType;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "analytics_event")
@Getter @Setter @Builder
@NoArgsConstructor @AllArgsConstructor
public class AnalyticsEvent {

    @Id
    @GeneratedValue
    @Column(name = "event_id", nullable = false, updatable = false)
    private UUID id;

    @Enumerated(EnumType.STRING)
    @Column(name = "event_type", nullable = false, length = 50)
    private AnalyticsEventType eventType;

    @Column(name = "actor_user_id")
    private UUID actorUserId;

    @Column(name = "target_type", length = 30)
    private String targetType;

    @Column(name = "target_id")
    private UUID targetId;

    @Column(name = "source_service", nullable = false, length = 50)
    private String sourceService;

    @Column(name = "occurred_at", nullable = false)
    private Instant occurredAt;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "payload_json", columnDefinition = "jsonb")
    private String payloadJson;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;
}