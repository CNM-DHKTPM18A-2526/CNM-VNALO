package iuh.cnm.vnalo.content_service.repository;

import iuh.cnm.vnalo.content_service.model.entity.Story;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface StoryRepository extends JpaRepository<Story, UUID> {

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