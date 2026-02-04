package iuh.cnm.vnalo.core_service.repository.user;

import iuh.cnm.vnalo.core_service.model.entity.user.UserProfile;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.UUID;

@Repository
public interface UserProfileRepository extends JpaRepository<UserProfile, UUID> {

    @Query("SELECT p FROM UserProfile p WHERE LOWER(p.displayName) LIKE LOWER(CONCAT('%', :keyword, '%'))")
    Page<UserProfile> searchByDisplayName(@Param("keyword") String keyword, Pageable pageable);
}
