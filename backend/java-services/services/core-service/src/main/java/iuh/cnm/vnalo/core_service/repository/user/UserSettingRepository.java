package iuh.cnm.vnalo.core_service.repository.user;

import iuh.cnm.vnalo.core_service.model.entity.user.UserSetting;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.UUID;

/**
 * Repository for UserSetting entity.
 */
@Repository
public interface UserSettingRepository extends JpaRepository<UserSetting, UUID> {
}
