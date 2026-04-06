package iuh.cnm.vnalo.analytics_service.repository;

import iuh.cnm.vnalo.analytics_service.model.entity.BackfillJob;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface BackfillJobRepository extends JpaRepository<BackfillJob, UUID> {
	Optional<BackfillJob> findFirstByFromDateAndToDateOrderByStartedAtDesc(LocalDate fromDate, LocalDate toDate);

	long deleteByFinishedAtBefore(java.time.Instant cutoff);
}