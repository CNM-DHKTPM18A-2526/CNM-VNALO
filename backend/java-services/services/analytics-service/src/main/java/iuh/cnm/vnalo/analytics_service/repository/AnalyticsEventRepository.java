package iuh.cnm.vnalo.analytics_service.repository;

import iuh.cnm.vnalo.analytics_service.model.entity.AnalyticsEvent;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.UUID;

@Repository
public interface AnalyticsEventRepository extends JpaRepository<AnalyticsEvent, UUID> {
	long deleteByOccurredAtBefore(Instant cutoff);
}