package iuh.cnm.vnalo.moderation_service.model.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "moderation_audit_log")
@Getter @Setter @Builder
@NoArgsConstructor @AllArgsConstructor
public class ModerationAuditLog {

    @Id
    @GeneratedValue
    @Column(name = "audit_log_id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "report_id")
    private UUID reportId;

    @Column(name = "case_id")
    private UUID caseId;

    @Column(name = "action", nullable = false, length = 50)
    private String action;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "old_value_json", columnDefinition = "jsonb")
    private String oldValueJson;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "new_value_json", columnDefinition = "jsonb")
    private String newValueJson;

    @Column(name = "performed_by", nullable = false)
    private UUID performedBy;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;
}