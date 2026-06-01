package iuh.cnm.vnalo.core_service.repository.auth;

import iuh.cnm.vnalo.core_service.model.entity.auth.AuthSessionAudit;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Repository
public interface AuthSessionAuditRepository extends JpaRepository<AuthSessionAudit, UUID> {
    List<AuthSessionAudit> findByAccountIdOrderByCreatedAtDesc(UUID accountId, Pageable pageable);

    List<AuthSessionAudit> findAllByOrderByCreatedAtDesc(Pageable pageable);

    long countByCreatedAtAfter(Instant since);

    @Query("SELECT COUNT(a) FROM AuthSessionAudit a WHERE a.createdAt >= :since AND a.eventType = :eventType")
    long countByEventTypeSince(@Param("eventType") String eventType, @Param("since") Instant since);
}
