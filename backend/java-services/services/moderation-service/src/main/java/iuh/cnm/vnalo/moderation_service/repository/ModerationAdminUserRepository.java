package iuh.cnm.vnalo.moderation_service.repository;

import iuh.cnm.vnalo.moderation_service.model.entity.ModerationAdminUser;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface ModerationAdminUserRepository extends JpaRepository<ModerationAdminUser, UUID> {
    Optional<ModerationAdminUser> findByUserIdAndIsActiveTrue(UUID userId);
}