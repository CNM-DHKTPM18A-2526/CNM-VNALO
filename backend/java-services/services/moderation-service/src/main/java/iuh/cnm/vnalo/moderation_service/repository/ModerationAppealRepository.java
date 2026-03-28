package iuh.cnm.vnalo.moderation_service.repository;

import iuh.cnm.vnalo.moderation_service.model.entity.ModerationAppeal;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.UUID;

@Repository
public interface ModerationAppealRepository extends JpaRepository<ModerationAppeal, UUID> {
}