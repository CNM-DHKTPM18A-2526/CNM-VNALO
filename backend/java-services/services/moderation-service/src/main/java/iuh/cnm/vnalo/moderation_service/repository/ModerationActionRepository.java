package iuh.cnm.vnalo.moderation_service.repository;

import iuh.cnm.vnalo.moderation_service.model.entity.ModerationAction;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface ModerationActionRepository extends JpaRepository<ModerationAction, UUID> {
    List<ModerationAction> findByCaseIdOrderByCreatedAtDesc(UUID caseId);
}