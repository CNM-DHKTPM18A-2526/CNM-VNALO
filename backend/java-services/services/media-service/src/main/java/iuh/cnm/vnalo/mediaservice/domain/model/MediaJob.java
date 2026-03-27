package iuh.cnm.vnalo.mediaservice.domain.model;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "media_job", indexes = {
        @Index(name = "idx_media_job_media", columnList = "media_id"),
        @Index(name = "idx_media_job_status", columnList = "status, next_run_at")
})
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MediaJob {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "media_job_id")
    private UUID mediaJobId;

    @Column(name = "media_id", nullable = false)
    private UUID mediaId;

    @Column(name = "job_type", nullable = false, length = 20)
    private String jobType;  // THUMBNAIL, COMPRESS, TRANSCODE

    @Builder.Default
    @Column(length = 20)
    private String status = "PENDING";  // PENDING, RUNNING, DONE, FAILED

    @Column(name = "routing_key", length = 100)
    private String routingKey;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "payload_json", columnDefinition = "jsonb")
    private String payloadJson;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "result_json", columnDefinition = "jsonb")
    private String resultJson;

    @Builder.Default
    @Column(name = "retry_count")
    private Integer retryCount = 0;

    @Column(name = "next_run_at")
    private LocalDateTime nextRunAt;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;
}
