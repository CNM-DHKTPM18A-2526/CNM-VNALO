package iuh.cnm.vnalo.analytics_service.repository;

import iuh.cnm.vnalo.analytics_service.model.entity.AnalyticsEvent;
import iuh.cnm.vnalo.analytics_service.model.enums.AnalyticsEventType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Repository
public interface AnalyticsEventRepository extends JpaRepository<AnalyticsEvent, UUID> {
	long deleteByOccurredAtBefore(Instant cutoff);

    long countByOccurredAtBetween(Instant from, Instant to);

    long countByEventTypeAndOccurredAtBetween(AnalyticsEventType eventType, Instant from, Instant to);

    @Query("SELECT COUNT(DISTINCT e.actorUserId) FROM AnalyticsEvent e WHERE e.occurredAt BETWEEN :from AND :to AND e.actorUserId IS NOT NULL")
    long countDistinctActorsBetween(@Param("from") Instant from, @Param("to") Instant to);

    List<AnalyticsEvent> findTop5000ByOccurredAtBetweenOrderByOccurredAtDesc(Instant from, Instant to);
}
