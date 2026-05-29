package iuh.cnm.vnalo.content_service.repository;

import iuh.cnm.vnalo.content_service.model.entity.Story;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.OffsetDateTime;
import java.util.List;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface StoryRepository extends JpaRepository<Story, UUID> {

    @Query(value = "SELECT * FROM content.story s WHERE s.status = :status AND s.expires_at > :now AND (" +
            " s.author_id = :userId OR " +
            " s.visibility = 'PUBLIC' OR " +
            " s.visibility = 'FRIENDS' OR " +
            " (s.visibility = 'SOME_FRIENDS' AND s.included_ids @> CAST(CONCAT('[', '\"', CAST(:userId AS text), '\"', ']') AS jsonb)) OR " +
            " (s.visibility = 'FRIENDS_EXCEPT' AND NOT (s.excluded_ids @> CAST(CONCAT('[', '\"', CAST(:userId AS text), '\"', ']') AS jsonb))) " +
            ") ORDER BY s.created_at DESC", nativeQuery = true)
    List<Story> findActiveStoriesForUser(
            @Param("status") String status,
            @Param("now") OffsetDateTime now,
            @Param("userId") UUID userId
    );

    List<Story> findByStatusAndExpiresAtAfterOrderByCreatedAtDesc(
            String status,
            OffsetDateTime now
    );

    Optional<Story> findByStoryIdAndStatusAndExpiresAtAfter(
            UUID storyId,
            String status,
            OffsetDateTime now
    );

    List<Story> findByStatusAndExpiresAtBefore(
            String status,
            OffsetDateTime now
    );
}