package iuh.cnm.vnalo.core_service.repository.social;

import iuh.cnm.vnalo.core_service.model.entity.social.ContactSync;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ContactSyncRepository extends JpaRepository<ContactSync, UUID> {

    Optional<ContactSync> findByUserIdAndPhoneNumber(UUID userId, String phoneNumber);

    Page<ContactSync> findByUserIdAndMatchedUserIdIsNotNull(UUID userId, Pageable pageable);

    Page<ContactSync> findByUserId(UUID userId, Pageable pageable);

    List<ContactSync> findByUserIdAndMatchedUserIdIsNull(UUID userId);

    void deleteByUserId(UUID userId);
}
