package iuh.cnm.vnalo.core_service.repository.auth;

import iuh.cnm.vnalo.core_service.model.entity.auth.AuthSessionAudit;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface AuthSessionAuditRepository extends JpaRepository<AuthSessionAudit, UUID> {
    List<AuthSessionAudit> findByAccountIdOrderByCreatedAtDesc(UUID accountId, Pageable pageable);
}
