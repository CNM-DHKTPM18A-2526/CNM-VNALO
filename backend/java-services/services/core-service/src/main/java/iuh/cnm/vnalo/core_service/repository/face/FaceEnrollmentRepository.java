package iuh.cnm.vnalo.core_service.repository.face;

import iuh.cnm.vnalo.core_service.model.entity.face.FaceEnrollment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface FaceEnrollmentRepository extends JpaRepository<FaceEnrollment, Long> {

    Optional<FaceEnrollment> findByUserId(UUID userId);

    Optional<FaceEnrollment> findByUserIdAndIsActiveTrue(UUID userId);

    boolean existsByUserId(UUID userId);

    void deleteByUserId(UUID userId);
}
