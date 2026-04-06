package iuh.cnm.vnalo.analytics_service.repository;

import iuh.cnm.vnalo.analytics_service.model.entity.AnalyticsDailyMetric;
import iuh.cnm.vnalo.analytics_service.model.enums.MetricKey;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface AnalyticsDailyMetricRepository extends JpaRepository<AnalyticsDailyMetric, UUID> {
    List<AnalyticsDailyMetric> findByMetricDateBetweenAndMetricKeyOrderByMetricDateAsc(
            LocalDate from, LocalDate to, MetricKey metricKey
    );

    Optional<AnalyticsDailyMetric> findByMetricDateAndMetricKeyAndDimensionKeyAndDimensionValue(
            LocalDate metricDate, MetricKey metricKey, String dimensionKey, String dimensionValue
    );

        long deleteByMetricDateBefore(LocalDate cutoffDate);
}