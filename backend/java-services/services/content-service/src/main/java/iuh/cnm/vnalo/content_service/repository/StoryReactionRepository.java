package iuh.cnm.vnalo.content_service.repository;

import iuh.cnm.vnalo.content_service.model.entity.StoryReaction;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface StoryReactionRepository extends JpaRepository<StoryReaction, UUID> {

    Optional<StoryReaction> findByStoryIdAndUserId(UUID storyId, UUID userId);

    List<StoryReaction> findByStoryIdOrderByCreatedAtDesc(UUID storyId);
}
