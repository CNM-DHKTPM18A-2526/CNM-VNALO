package iuh.cnm.vnalo.core_service.repository.social;

import iuh.cnm.vnalo.core_service.model.entity.social.Friendship;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface FriendshipRepository extends JpaRepository<Friendship, UUID> {

    @Query("SELECT COUNT(f) > 0 FROM Friendship f WHERE " +
           "(f.userIdFrom = :userA AND f.userIdTo = :userB) OR (f.userIdFrom = :userB AND f.userIdTo = :userA)")
    boolean areFriends(@Param("userA") UUID userA, @Param("userB") UUID userB);

    @Query("SELECT f FROM Friendship f WHERE " +
           "(f.userIdFrom = :userA AND f.userIdTo = :userB) OR (f.userIdFrom = :userB AND f.userIdTo = :userA)")
    Optional<Friendship> findFriendship(@Param("userA") UUID userA, @Param("userB") UUID userB);

    @Query("SELECT f FROM Friendship f WHERE f.userIdFrom = :userId OR f.userIdTo = :userId ORDER BY f.createdAt DESC")
    Page<Friendship> findFriendships(@Param("userId") UUID userId, Pageable pageable);

    @Query("SELECT f FROM Friendship f WHERE f.userIdFrom = :userId OR f.userIdTo = :userId")
    List<Friendship> findAllFriendships(@Param("userId") UUID userId);

    @Query("SELECT CASE WHEN f.userIdFrom = :userId THEN f.userIdTo ELSE f.userIdFrom END FROM Friendship f WHERE f.userIdFrom = :userId OR f.userIdTo = :userId")
    List<UUID> findFriendIds(@Param("userId") UUID userId);

    @Query("SELECT COUNT(f) FROM Friendship f WHERE f.userIdFrom = :userId OR f.userIdTo = :userId")
    long countFriends(@Param("userId") UUID userId);

    @Query("SELECT f FROM Friendship f WHERE (f.userIdFrom = :userId AND f.userIdTo IN :targetIds) OR (f.userIdTo = :userId AND f.userIdFrom IN :targetIds)")
    List<Friendship> findFriendshipsBetween(@Param("userId") UUID userId, @Param("targetIds") List<UUID> targetIds);

    @Modifying
    @Query("DELETE FROM Friendship f WHERE (f.userIdFrom = :userA AND f.userIdTo = :userB) OR (f.userIdFrom = :userB AND f.userIdTo = :userA)")
    void deleteFriendship(@Param("userA") UUID userA, @Param("userB") UUID userB);
}
