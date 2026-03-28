package iuh.cnm.vnalo.moderation_service.model.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "moderation_report_evidence")
@Getter @Setter @Builder
@NoArgsConstructor @AllArgsConstructor
public class ModerationReportEvidence {

    @Id
    @GeneratedValue
    @Column(name = "evidence_id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "report_id", nullable = false)
    private UUID reportId;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "snapshot_json", nullable = false, columnDefinition = "jsonb")
    private String snapshotJson;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;
}