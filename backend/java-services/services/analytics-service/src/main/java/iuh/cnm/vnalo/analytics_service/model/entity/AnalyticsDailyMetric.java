package iuh.cnm.vnalo.analytics_service.model.entity;

import iuh.cnm.vnalo.analytics_service.model.enums.MetricKey;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(
    name = "analytics_daily_metric",
    uniqueConstraints = {
        @UniqueConstraint(
            name = "uq_daily_metric",
            columnNames = {"metric_date", "metric_key", "dimension_key", "dimension_value"}
        )
    }
)
@Getter @Setter @Builder
@NoArgsConstructor @AllArgsConstructor
public class AnalyticsDailyMetric {

    @Id
    @GeneratedValue
    @Column(name = "metric_id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "metric_date", nullable = false)
    private LocalDate metricDate;

    @Enumerated(EnumType.STRING)
    @Column(name = "metric_key", nullable = false, length = 50)
    private MetricKey metricKey;

    @Column(name = "dimension_key", length = 50)
    private String dimensionKey;

    @Column(name = "dimension_value", length = 100)
    private String dimensionValue;

    @Column(name = "metric_value", nullable = false)
    private Long metricValue;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;
}