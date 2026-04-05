package iuh.cnm.vnalo.moderation_service.model.entity;

import iuh.cnm.vnalo.moderation_service.model.enums.ModerationCaseStatus;
import iuh.cnm.vnalo.moderation_service.model.enums.ModerationDecision;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "moderation_case")
@Getter @Setter @Builder
@NoArgsConstructor @AllArgsConstructor
public class ModerationCase {

    @Id
    @GeneratedValue
    @Column(name = "case_id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "report_id", nullable = false, unique = true)
    private UUID reportId;

    @Column(name = "assigned_moderator_id")
    private UUID assignedModeratorId;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private ModerationCaseStatus status;

    @Enumerated(EnumType.STRING)
    @Column(name = "decision", nullable = false, length = 30)
    private ModerationDecision decision;

    @Column(name = "note", length = 1000)
    private String note;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "resolved_at")
    private Instant resolvedAt;
}