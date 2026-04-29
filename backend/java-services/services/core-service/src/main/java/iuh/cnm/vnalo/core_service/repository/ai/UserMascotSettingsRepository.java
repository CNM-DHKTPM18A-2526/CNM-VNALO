package iuh.cnm.vnalo.core_service.repository.ai;

import iuh.cnm.vnalo.core_service.model.entity.ai.UserMascotSettings;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface UserMascotSettingsRepository extends JpaRepository<UserMascotSettings, UUID> {
    Optional<UserMascotSettings> findByUserId(UUID userId);
}
