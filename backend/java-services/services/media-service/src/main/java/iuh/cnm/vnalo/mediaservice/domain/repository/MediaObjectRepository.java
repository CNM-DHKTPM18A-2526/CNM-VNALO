package iuh.cnm.vnalo.mediaservice.domain.repository;

import iuh.cnm.vnalo.mediaservice.domain.model.MediaCategory;
import iuh.cnm.vnalo.mediaservice.domain.model.MediaObject;
import iuh.cnm.vnalo.mediaservice.domain.model.MediaStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Repository
public interface MediaObjectRepository extends JpaRepository<MediaObject, UUID> {

    // List by owner (all media)
    Page<MediaObject> findByOwnerUserId(UUID ownerUserId, Pageable pageable);

    // List by owner + filter category
    Page<MediaObject> findByOwnerUserIdAndMediaCategory(UUID ownerUserId, MediaCategory category, Pageable pageable);

    // List by conversation (via access scope)
    @Query("SELECT m FROM MediaObject m JOIN MediaAccessScope s ON m.id = s.mediaId " +
           "WHERE s.scopeType = 'CONVERSATION' AND s.scopeId = :conversationId")
    Page<MediaObject> findByConversationId(@Param("conversationId") UUID conversationId, Pageable pageable);

    // List by conversation + filter category
    @Query("SELECT m FROM MediaObject m JOIN MediaAccessScope s ON m.id = s.mediaId " +
           "WHERE s.scopeType = 'CONVERSATION' AND s.scopeId = :conversationId AND m.mediaCategory = :category")
    Page<MediaObject> findByConversationIdAndCategory(@Param("conversationId") UUID conversationId,
                                                      @Param("category") MediaCategory category,
                                                      Pageable pageable);

    // Filter by category only (all owners)
    Page<MediaObject> findByMediaCategory(MediaCategory category, Pageable pageable);

    // Find expired stories for cleanup
    List<MediaObject> findByMediaCategoryAndStatusAndExpiresAtBefore(
            MediaCategory category, MediaStatus status, LocalDateTime before);
}
