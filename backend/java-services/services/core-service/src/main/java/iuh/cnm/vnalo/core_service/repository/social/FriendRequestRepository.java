package iuh.cnm.vnalo.core_service.repository.social;

import iuh.cnm.vnalo.core_service.model.entity.social.FriendRequest;
import iuh.cnm.vnalo.core_service.model.enums.FriendRequestStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface FriendRequestRepository extends JpaRepository<FriendRequest, UUID> {

    @Query("SELECT fr FROM FriendRequest fr WHERE fr.userIdFrom = :fromUserId AND fr.userIdTo = :toUserId AND fr.status = 'PENDING'")
    Optional<FriendRequest> findPendingRequest(@Param("fromUserId") UUID fromUserId, @Param("toUserId") UUID toUserId);

    @Query("SELECT COUNT(fr) > 0 FROM FriendRequest fr WHERE " +
           "((fr.userIdFrom = :userA AND fr.userIdTo = :userB) OR (fr.userIdFrom = :userB AND fr.userIdTo = :userA)) " +
           "AND fr.status = 'PENDING'")
    boolean existsPendingBetween(@Param("userA") UUID userA, @Param("userB") UUID userB);

    Page<FriendRequest> findByUserIdToAndStatusOrderByCreatedAtDesc(UUID userIdTo, FriendRequestStatus status, Pageable pageable);

    Page<FriendRequest> findByUserIdFromOrderByCreatedAtDesc(UUID userIdFrom, Pageable pageable);

    Page<FriendRequest> findByUserIdFromAndStatusOrderByCreatedAtDesc(UUID userIdFrom, FriendRequestStatus status, Pageable pageable);

    default Page<FriendRequest> findPendingSentRequests(UUID userId, Pageable pageable) {
        return findByUserIdFromAndStatusOrderByCreatedAtDesc(userId, FriendRequestStatus.PENDING, pageable);
    }

    default Page<FriendRequest> findPendingRequestsToUser(UUID userId, Pageable pageable) {
        return findByUserIdToAndStatusOrderByCreatedAtDesc(userId, FriendRequestStatus.PENDING, pageable);
    }

    long countByUserIdToAndStatus(UUID userIdTo, FriendRequestStatus status);

    default long countPendingRequests(UUID userId) {
        return countByUserIdToAndStatus(userId, FriendRequestStatus.PENDING);
    }
}
