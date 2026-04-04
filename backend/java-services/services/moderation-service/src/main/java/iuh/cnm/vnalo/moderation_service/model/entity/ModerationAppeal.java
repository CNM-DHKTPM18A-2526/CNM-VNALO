package iuh.cnm.vnalo.moderation_service.model.entity;

import iuh.cnm.vnalo.moderation_service.model.enums.AppealStatus;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "moderation_appeal")
@Getter @Setter @Builder
@NoArgsConstructor @AllArgsConstructor
public class ModerationAppeal {

    @Id
    @GeneratedValue
    @Column(name = "appeal_id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "case_id", nullable = false)
    private UUID caseId;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "reason", nullable = false, length = 1000)
    private String reason;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private AppealStatus status;

    @Column(name = "moderator_response")
    private String moderatorResponse;

    @Column(name = "moderator_id")
    private UUID moderatorId;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;
}