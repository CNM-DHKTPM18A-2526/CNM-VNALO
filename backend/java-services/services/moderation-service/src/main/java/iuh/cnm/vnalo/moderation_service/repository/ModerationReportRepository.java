package iuh.cnm.vnalo.moderation_service.repository;

import iuh.cnm.vnalo.moderation_service.model.entity.ModerationReport;
import iuh.cnm.vnalo.moderation_service.model.enums.ReportTargetType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.UUID;

@Repository
public interface ModerationReportRepository extends JpaRepository<ModerationReport, UUID>, JpaSpecificationExecutor<ModerationReport> {
    Page<ModerationReport> findByReporterUserId(UUID reporterUserId, Pageable pageable);

    boolean existsByReporterUserIdAndTargetTypeAndTargetIdAndReasonCodeAndCreatedAtAfter(
            UUID reporterUserId,
            ReportTargetType targetType,
            UUID targetId,
            String reasonCode,
            Instant createdAtAfter
    );
}