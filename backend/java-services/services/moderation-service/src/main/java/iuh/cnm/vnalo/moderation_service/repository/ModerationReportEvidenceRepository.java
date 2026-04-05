package iuh.cnm.vnalo.moderation_service.repository;

import iuh.cnm.vnalo.moderation_service.model.entity.ModerationReportEvidence;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface ModerationReportEvidenceRepository extends JpaRepository<ModerationReportEvidence, UUID> {
    Optional<ModerationReportEvidence> findByReportId(UUID reportId);
}