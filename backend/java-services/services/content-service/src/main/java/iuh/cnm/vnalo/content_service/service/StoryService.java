package iuh.cnm.vnalo.content_service.service;

import iuh.cnm.vnalo.content_service.exception.ApiException;
import iuh.cnm.vnalo.content_service.exception.ErrorCode;
import iuh.cnm.vnalo.content_service.model.dto.CreateStoryRequest;
import iuh.cnm.vnalo.content_service.model.dto.StoryResponse;
import iuh.cnm.vnalo.content_service.model.dto.StoryViewResponse;
import iuh.cnm.vnalo.content_service.model.entity.Story;
import iuh.cnm.vnalo.content_service.model.entity.StoryView;
import iuh.cnm.vnalo.content_service.repository.StoryRepository;
import iuh.cnm.vnalo.content_service.repository.StoryViewRepository;
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
    private final StoryViewRepository storyViewRepository;

    @Transactional
    public StoryResponse createStory(UUID authorId, CreateStoryRequest request) {
        Story story = Story.builder()
                .authorId(authorId)
                .mediaUrl(request.getMediaUrl())
                .caption(request.getCaption())
                .visibility(request.getVisibility() == null || request.getVisibility().isBlank()
                        ? "PUBLIC"
                        : request.getVisibility().trim().toUpperCase())
                .status("ACTIVE")
                .expiresAt(OffsetDateTime.now().plusHours(24))
                .build();

        Story saved = storyRepository.saveAndFlush(story);
        return map(saved);
    }

    @Transactional(readOnly = true)
    public List<StoryResponse> getActiveStories() {
        List<Story> stories = storyRepository.findByStatusAndExpiresAtAfterOrderByCreatedAtDesc(
                "ACTIVE",
                OffsetDateTime.now()
        );

        return stories.stream().map(this::map).toList();
    }

    @Transactional
    public void deleteStory(UUID storyId, UUID userId) {
        Story story = storyRepository.findById(storyId)
                .orElseThrow(() -> new ApiException(ErrorCode.STORY_NOT_FOUND));

        if (!story.getAuthorId().equals(userId)) {
            throw new ApiException(ErrorCode.FORBIDDEN);
        }

        story.setStatus("DELETED");
        storyRepository.save(story);
    }

    @Transactional
    public void markViewed(UUID storyId, UUID viewerId) {
        Story story = storyRepository.findByStoryIdAndStatusAndExpiresAtAfter(
                        storyId,
                        "ACTIVE",
                        OffsetDateTime.now()
                )
                .orElseThrow(() -> new ApiException(ErrorCode.STORY_NOT_FOUND));

        if (storyViewRepository.existsByStoryIdAndViewerId(storyId, viewerId)) {
            return;
        }

        StoryView storyView = StoryView.builder()
                .storyId(storyId)
                .viewerId(viewerId)
                .viewedAt(OffsetDateTime.now())
                .build();

        storyViewRepository.save(storyView);
    }

    @Transactional(readOnly = true)
    public List<StoryViewResponse> getStoryViews(UUID storyId) {
        Story story = storyRepository.findById(storyId)
                .orElseThrow(() -> new ApiException(ErrorCode.STORY_NOT_FOUND));

        return storyViewRepository.findByStoryIdOrderByViewedAtDesc(story.getStoryId())
                .stream()
                .map(this::mapView)
                .toList();
    }

    @Transactional
    public int expireStories() {
        List<Story> expiredStories = storyRepository.findByStatusAndExpiresAtBefore(
                "ACTIVE",
                OffsetDateTime.now()
        );

        expiredStories.forEach(story -> story.setStatus("EXPIRED"));
        storyRepository.saveAll(expiredStories);

        return expiredStories.size();
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

    private StoryViewResponse mapView(StoryView storyView) {
        return StoryViewResponse.builder()
                .viewId(storyView.getViewId())
                .storyId(storyView.getStoryId())
                .viewerId(storyView.getViewerId())
                .viewedAt(storyView.getViewedAt())
                .build();
    }
}