package iuh.cnm.vnalo.moderation_service.repository;

import iuh.cnm.vnalo.moderation_service.model.entity.ModerationCase;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface ModerationCaseRepository extends JpaRepository<ModerationCase, UUID> {
    Optional<ModerationCase> findByReportId(UUID reportId);
}