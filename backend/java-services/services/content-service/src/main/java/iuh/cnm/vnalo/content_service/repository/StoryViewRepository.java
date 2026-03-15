package iuh.cnm.vnalo.content_service.repository;

import iuh.cnm.vnalo.content_service.model.entity.StoryView;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface StoryViewRepository extends JpaRepository<StoryView, UUID> {

    boolean existsByStoryIdAndViewerId(UUID storyId, UUID viewerId);

}