package iuh.cnm.vnalo.moderation_service.repository;

import iuh.cnm.vnalo.moderation_service.model.entity.ModerationAuditLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface ModerationAuditLogRepository extends JpaRepository<ModerationAuditLog, UUID> {
    List<ModerationAuditLog> findByCaseIdOrderByCreatedAtDesc(UUID caseId);
}