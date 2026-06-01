package iuh.cnm.vnalo.content_service.repository;

import iuh.cnm.vnalo.content_service.model.entity.Story;
import org.springframework.data.jpa.repository.JpaRepository;

import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface StoryRepository extends JpaRepository<Story, UUID> {

    @Query("""
            SELECT s FROM Story s
            WHERE s.status = :status
              AND s.expiresAt > :now
            ORDER BY s.createdAt DESC
            """)
    List<Story> findActiveStories(
            @Param("status") String status,
            @Param("now") OffsetDateTime now
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