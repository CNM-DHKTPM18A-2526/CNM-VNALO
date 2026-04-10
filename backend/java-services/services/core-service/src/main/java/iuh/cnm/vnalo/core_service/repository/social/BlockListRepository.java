package iuh.cnm.vnalo.core_service.repository.social;

import iuh.cnm.vnalo.core_service.model.entity.social.BlockList;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Repository for BlockList entity.
 */
@Repository
public interface BlockListRepository extends JpaRepository<BlockList, UUID> {

    /**
     * Check if user A has blocked user B.
     */
    boolean existsByBlockerIdAndBlockedId(UUID blockerId, UUID blockedId);

    /**
     * Check if there is any block between two users (bidirectional).
     */
    @Query("SELECT COUNT(b) > 0 FROM BlockList b WHERE " +
           "(b.blockerId = :userA AND b.blockedId = :userB) OR (b.blockerId = :userB AND b.blockedId = :userA)")
    boolean existsBlockBetween(@Param("userA") UUID userA, @Param("userB") UUID userB);

    /**
     * Find block record by blocker and blocked IDs.
     */
    Optional<BlockList> findByBlockerIdAndBlockedId(UUID blockerId, UUID blockedId);

    /**
     * Get paginated list of blocked users.
     */
    Page<BlockList> findByBlockerIdOrderByCreatedAtDesc(UUID blockerId, Pageable pageable);

    /**
     * Get list of user IDs that have been blocked by the specified user.
     */
    @Query("SELECT b.blockedId FROM BlockList b WHERE b.blockerId = :blockerId")
    List<UUID> findBlockedIds(@Param("blockerId") UUID blockerId);

    /**
     * Get list of user IDs that have blocked the specified user.
     */
    @Query("SELECT b.blockerId FROM BlockList b WHERE b.blockedId = :blockedId")
    List<UUID> findBlockerIds(@Param("blockedId") UUID blockedId);

    @Query("SELECT b FROM BlockList b WHERE (b.blockerId = :userId AND b.blockedId IN :targetIds) OR (b.blockedId = :userId AND b.blockerId IN :targetIds)")
    List<BlockList> findBlocksBetween(@Param("userId") UUID userId, @Param("targetIds") List<UUID> targetIds);

    /**
     * Delete block record.
     */
    void deleteByBlockerIdAndBlockedId(UUID blockerId, UUID blockedId);

    /**
     * Count total blocked users by the specified user.
     */
    long countByBlockerId(UUID blockerId);
}
