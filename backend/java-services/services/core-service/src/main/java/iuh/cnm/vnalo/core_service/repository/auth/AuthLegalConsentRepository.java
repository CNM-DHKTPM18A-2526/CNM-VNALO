package iuh.cnm.vnalo.core_service.repository.auth;

import iuh.cnm.vnalo.core_service.model.entity.auth.AuthLegalConsent;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.UUID;

@Repository
public interface AuthLegalConsentRepository extends JpaRepository<AuthLegalConsent, UUID> {
    long countByGrantedTrue();

    long countByConsentTypeAndGrantedTrue(String consentType);

    long countByConsentTypeAndGrantedTrueAndGrantedAtAfter(String consentType, Instant since);
}