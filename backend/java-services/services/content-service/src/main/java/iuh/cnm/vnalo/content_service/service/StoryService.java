package iuh.cnm.vnalo.content_service.service;

import iuh.cnm.vnalo.content_service.exception.ApiException;
import iuh.cnm.vnalo.content_service.exception.ErrorCode;
import iuh.cnm.vnalo.content_service.model.dto.CreateStoryRequest;
import iuh.cnm.vnalo.content_service.model.dto.StoryReactionResponse;
import iuh.cnm.vnalo.content_service.model.dto.StoryResponse;
import iuh.cnm.vnalo.content_service.model.dto.StoryViewResponse;
import iuh.cnm.vnalo.content_service.model.entity.Story;
import iuh.cnm.vnalo.content_service.model.entity.StoryReaction;
import iuh.cnm.vnalo.content_service.model.entity.StoryView;
import iuh.cnm.vnalo.content_service.repository.StoryReactionRepository;
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
    private final StoryReactionRepository storyReactionRepository;


    private String normalizeVisibility(String visibility) {
        if (visibility == null || visibility.isBlank()) {
            return "PUBLIC";
        }

        String normalized = visibility.trim().toUpperCase();
        return switch (normalized) {
            case "PUBLIC", "FRIENDS", "PRIVATE" -> normalized;
            default -> "PUBLIC";
        };
    }

    public boolean canViewStory(Story story, UUID userId) {
        if (story.getAuthorId().equals(userId)) return true;

        return switch (story.getVisibility()) {
            case "PUBLIC", "FRIENDS" -> true;
            case "PRIVATE" -> false;
            default -> false;
        };
    }

    @Transactional
    public StoryResponse createStory(UUID authorId, CreateStoryRequest request) {
        Story story = Story.builder()
                .authorId(authorId)
                .mediaUrl(request.getMediaUrl())
                .caption(request.getCaption())
                .visibility(normalizeVisibility(request.getVisibility()))
                .status("ACTIVE")
                .expiresAt(OffsetDateTime.now().plusHours(24))
                .build();

        Story saved = storyRepository.saveAndFlush(story);
        return map(saved);
    }

    @Transactional(readOnly = true)
    public List<StoryResponse> getActiveStories(UUID userId) {
        List<Story> stories = storyRepository.findActiveStoriesForUser(
                "ACTIVE",
                OffsetDateTime.now(),
                userId
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

        if (!canViewStory(story, viewerId)) {
            throw new ApiException(ErrorCode.FORBIDDEN);
        }

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
    public List<StoryViewResponse> getStoryViews(UUID storyId, UUID userId) {
        Story story = storyRepository.findById(storyId)
                .orElseThrow(() -> new ApiException(ErrorCode.STORY_NOT_FOUND));

        if (!story.getAuthorId().equals(userId)) {
            throw new ApiException(ErrorCode.FORBIDDEN);
        }

        return storyViewRepository.findByStoryIdOrderByViewedAtDesc(story.getStoryId())
                .stream()
                .map(this::mapView)
                .toList();
    }

    @Transactional
    public StoryReactionResponse reactToStory(UUID storyId, UUID userId, String reactionType) {
        Story story = storyRepository.findByStoryIdAndStatusAndExpiresAtAfter(
                        storyId,
                        "ACTIVE",
                        OffsetDateTime.now()
                )
                .orElseThrow(() -> new ApiException(ErrorCode.STORY_NOT_FOUND));

        if (!canViewStory(story, userId)) {
            throw new ApiException(ErrorCode.FORBIDDEN);
        }

        String normalizedReaction = reactionType == null || reactionType.isBlank()
                ? "LOVE"
                : reactionType.trim().toUpperCase();

        StoryReaction storyReaction = storyReactionRepository.findByStoryIdAndUserId(story.getStoryId(), userId)
                .orElseGet(() -> StoryReaction.builder()
                        .storyId(story.getStoryId())
                        .userId(userId)
                        .build());

        storyReaction.setReactionType(normalizedReaction);
        StoryReaction saved = storyReactionRepository.save(storyReaction);
        

        
        return mapReaction(saved);
    }

    @Transactional
    public void removeStoryReaction(UUID storyId, UUID userId) {
        if (!storyRepository.existsById(storyId)) {
            throw new ApiException(ErrorCode.STORY_NOT_FOUND);
        }

        storyReactionRepository.findByStoryIdAndUserId(storyId, userId)
                .ifPresent(storyReactionRepository::delete);
    }

    @Transactional(readOnly = true)
    public List<StoryReactionResponse> getStoryReactions(UUID storyId, UUID userId) {
        Story story = storyRepository.findById(storyId)
                .orElseThrow(() -> new ApiException(ErrorCode.STORY_NOT_FOUND));

        if (!story.getAuthorId().equals(userId)) {
            throw new ApiException(ErrorCode.FORBIDDEN);
        }

        return storyReactionRepository.findByStoryIdOrderByCreatedAtDesc(storyId)
                .stream()
                .map(this::mapReaction)
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

    private StoryReactionResponse mapReaction(StoryReaction storyReaction) {
        return StoryReactionResponse.builder()
                .storyReactionId(storyReaction.getStoryReactionId())
                .storyId(storyReaction.getStoryId())
                .userId(storyReaction.getUserId())
                .reactionType(storyReaction.getReactionType())
                .createdAt(storyReaction.getCreatedAt())
                .build();
    }
}
