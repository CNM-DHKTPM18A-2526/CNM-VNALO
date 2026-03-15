package iuh.cnm.vnalo.content_service.service;

import iuh.cnm.vnalo.content_service.model.dto.CreateStoryRequest;
import iuh.cnm.vnalo.content_service.model.dto.StoryResponse;
import iuh.cnm.vnalo.content_service.model.entity.Story;
import iuh.cnm.vnalo.content_service.repository.StoryRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class StoryService {

    private final StoryRepository storyRepository;

    @Transactional
    public StoryResponse createStory(UUID authorId, CreateStoryRequest request) {

        Story story = Story.builder()
                .authorId(authorId)
                .mediaUrl(request.getMediaUrl())
                .caption(request.getCaption())
                .visibility(request.getVisibility() == null ? "PUBLIC" : request.getVisibility())
                .status("ACTIVE")
                .expiresAt(OffsetDateTime.now().plusHours(24))
                .build();

        Story saved = storyRepository.save(story);

        return map(saved);
    }

    public List<StoryResponse> getActiveStories() {

        List<Story> stories = storyRepository
                .findByStatusAndExpiresAtAfterOrderByCreatedAtDesc(
                        "ACTIVE",
                        OffsetDateTime.now()
                );

        return stories.stream().map(this::map).toList();
    }

    @Transactional
    public void deleteStory(UUID storyId, UUID userId) {

        Story story = storyRepository.findById(storyId)
                .orElseThrow();

        if (!story.getAuthorId().equals(userId)) {
            throw new RuntimeException("Forbidden");
        }

        story.setStatus("DELETED");

        storyRepository.save(story);
    }

    private StoryResponse map(Story story) {
        return StoryResponse.builder()
                .storyId(story.getStoryId())
                .authorId(story.getAuthorId())
                .mediaUrl(story.getMediaUrl())
                .caption(story.getCaption())
                .visibility(story.getVisibility())
                .expiresAt(story.getExpiresAt())
                .createdAt(story.getCreatedAt())
                .build();
    }
}