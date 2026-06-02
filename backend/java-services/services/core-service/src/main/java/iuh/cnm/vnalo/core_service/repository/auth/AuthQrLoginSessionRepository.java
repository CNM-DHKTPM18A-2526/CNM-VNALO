package iuh.cnm.vnalo.core_service.repository.auth;

import iuh.cnm.vnalo.core_service.model.entity.auth.AuthQrLoginSession;
import iuh.cnm.vnalo.core_service.model.enums.QrLoginSessionStatus;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

public interface AuthQrLoginSessionRepository extends JpaRepository<AuthQrLoginSession, UUID> {
    Optional<AuthQrLoginSession> findByQrToken(String qrToken);

    long countByStatus(QrLoginSessionStatus status);

    long countByCreatedAtAfter(Instant since);

    long countByApprovedAtAfter(Instant since);

    long countByConsumedAtAfter(Instant since);
}
