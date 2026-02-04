package iuh.cnm.vnalo.core_service.repository.user;

import iuh.cnm.vnalo.core_service.model.entity.user.UserPrivacySetting;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.UUID;

/**
 * Repository for UserPrivacySetting entity.
 */
@Repository
public interface UserPrivacySettingRepository extends JpaRepository<UserPrivacySetting, UUID> {
    // Primary key is userId, basic CRUD methods inherited from JpaRepository
}
