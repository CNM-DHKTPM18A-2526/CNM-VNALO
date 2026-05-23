package iuh.cnm.vnalo.core_service.repository.face;

import iuh.cnm.vnalo.core_service.model.entity.face.FaceVerificationLog;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Repository
public interface FaceVerificationLogRepository extends JpaRepository<FaceVerificationLog, Long> {

    Page<FaceVerificationLog> findByUserIdOrderByCreatedAtDesc(UUID userId, Pageable pageable);

    long countByUserIdAndVerifiedFalseAndCreatedAtAfter(UUID userId, Instant since);

    List<FaceVerificationLog> findByUserIdAndCreatedAtAfterOrderByCreatedAtDesc(UUID userId, Instant since);
}
