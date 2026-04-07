package iuh.cnm.vnalo.core_service.repository.auth;

import iuh.cnm.vnalo.core_service.model.entity.auth.AuthQrLoginSession;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface AuthQrLoginSessionRepository extends JpaRepository<AuthQrLoginSession, UUID> {
    Optional<AuthQrLoginSession> findByQrToken(String qrToken);
}
