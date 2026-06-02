package iuh.cnm.vnalo.core_service.repository.auth;

import iuh.cnm.vnalo.core_service.model.entity.auth.AuthAccount;
import iuh.cnm.vnalo.core_service.model.enums.AccountStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface AuthAccountRepository extends JpaRepository<AuthAccount, UUID> {

    Optional<AuthAccount> findByPhone(String phone);

    Optional<AuthAccount> findByEmailIgnoreCase(String email);

    List<AuthAccount> findAllByIdIn(Collection<UUID> ids);

    boolean existsByPhone(String phone);

    boolean existsByEmailIgnoreCase(String email);

    long countByStatus(AccountStatus status);

    @Query("SELECT COUNT(a) FROM AuthAccount a WHERE COALESCE(a.failedLoginCount, 0) > 0")
    long countAccountsWithFailedLogins();

    @Query("SELECT COALESCE(SUM(a.failedLoginCount), 0) FROM AuthAccount a")
    Long sumFailedLoginCount();
}
