package iuh.cnm.vnalo.content_service.service;

import iuh.cnm.vnalo.content_service.exception.ApiException;
import iuh.cnm.vnalo.content_service.exception.ErrorCode;
import iuh.cnm.vnalo.content_service.model.dto.CreatePostRequest;
import iuh.cnm.vnalo.content_service.model.dto.PostResponse;
import iuh.cnm.vnalo.content_service.model.dto.TimelineResponse;
import iuh.cnm.vnalo.content_service.model.dto.UpdatePostRequest;
import iuh.cnm.vnalo.content_service.model.entity.Post;
import iuh.cnm.vnalo.content_service.repository.PostRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.Locale;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class PostService {

    private final PostRepository postRepository;

    @Transactional
    public PostResponse createPost(UUID authorId, CreatePostRequest request) {
        String visibility = normalizeVisibility(request.getVisibility());

        Post post = Post.builder()
                .authorId(authorId)
                .contentText(request.getContentText())
                .mediaUrls(request.getMediaUrls() != null ? request.getMediaUrls() : new ArrayList<>())
                .visibility(visibility)
                .includedIds(request.getIncludedIds() != null ? request.getIncludedIds() : new ArrayList<>())
                .excludedIds(request.getExcludedIds() != null ? request.getExcludedIds() : new ArrayList<>())
                .status("ACTIVE")
                .build();

        Post saved = postRepository.saveAndFlush(post);
        return toResponse(saved);
    }

    @Transactional(readOnly = true)
    public TimelineResponse getTimeline(UUID userId, int page, int size) {
        int safePage = Math.max(page, 0);
        int safeSize = Math.min(Math.max(size, 1), 50);

        PageRequest pageable = PageRequest.of(safePage, safeSize);

        Page<Post> result = postRepository.findTimelineForUser("ACTIVE", userId, pageable);

        return TimelineResponse.builder()
                .items(result.getContent().stream().map(this::toResponse).toList())
                .page(result.getNumber())
                .size(result.getSize())
                .totalElements(result.getTotalElements())
                .totalPages(result.getTotalPages())
                .last(result.isLast())
                .build();
    }

    @Transactional(readOnly = true)
    public TimelineResponse getUserTimeline(UUID targetUserId, UUID requesterId, int page, int size) {
        int safePage = Math.max(page, 0);
        int safeSize = Math.min(Math.max(size, 1), 50);

        PageRequest pageable = PageRequest.of(safePage, safeSize);

        Page<Post> result = postRepository.findTimelineForUserProfile("ACTIVE", targetUserId, requesterId, pageable);

        return TimelineResponse.builder()
                .items(result.getContent().stream().map(this::toResponse).toList())
                .page(result.getNumber())
                .size(result.getSize())
                .totalElements(result.getTotalElements())
                .totalPages(result.getTotalPages())
                .last(result.isLast())
                .build();
    }

    @Transactional(readOnly = true)
    public PostResponse getPostById(UUID postId, UUID userId) {
        Post post = postRepository.findByPostIdAndStatus(postId, "ACTIVE")
                .orElseThrow(() -> new ApiException(ErrorCode.POST_NOT_FOUND));

        if (!canViewPost(post, userId)) {
            throw new ApiException(ErrorCode.FORBIDDEN);
        }

        return toResponse(post);
    }

    @Transactional
    public PostResponse updatePost(UUID postId, UUID userId, UpdatePostRequest request) {
        Post post = postRepository.findByPostIdAndStatus(postId, "ACTIVE")
                .orElseThrow(() -> new ApiException(ErrorCode.POST_NOT_FOUND));

        if (!post.getAuthorId().equals(userId)) {
            throw new ApiException(ErrorCode.FORBIDDEN);
        }

        if (request.getContentText() != null) {
            post.setContentText(request.getContentText());
        }

        if (request.getMediaUrls() != null) {
            post.setMediaUrls(request.getMediaUrls());
        }

        if (request.getVisibility() != null && !request.getVisibility().isBlank()) {
            post.setVisibility(normalizeVisibility(request.getVisibility()));
        }

        if (request.getIncludedIds() != null) {
            post.setIncludedIds(request.getIncludedIds());
        }

        if (request.getExcludedIds() != null) {
            post.setExcludedIds(request.getExcludedIds());
        }

        Post saved = postRepository.saveAndFlush(post);
        return toResponse(saved);
    }

    @Transactional
    public void deletePost(UUID postId, UUID userId) {
        Post post = postRepository.findByPostIdAndStatus(postId, "ACTIVE")
                .orElseThrow(() -> new ApiException(ErrorCode.POST_NOT_FOUND));

        if (!post.getAuthorId().equals(userId)) {
            throw new ApiException(ErrorCode.FORBIDDEN);
        }

        post.setStatus("DELETED");
        postRepository.save(post);
    }

    @Transactional
    public PostResponse sharePost(UUID postId, UUID userId) {
        Post post = postRepository.findByPostIdAndStatus(postId, "ACTIVE")
                .orElseThrow(() -> new ApiException(ErrorCode.POST_NOT_FOUND));

        if (!canViewPost(post, userId)) {
            throw new ApiException(ErrorCode.FORBIDDEN);
        }

        post.setShareCount(post.getShareCount() + 1);
        Post saved = postRepository.saveAndFlush(post);
        return toResponse(saved);
    }

    private String normalizeVisibility(String visibility) {
        if (visibility == null || visibility.isBlank()) {
            return "PUBLIC";
        }

        String normalized = visibility.trim().toUpperCase(Locale.ROOT);
        return switch (normalized) {
            case "PUBLIC", "FRIENDS", "PRIVATE", "SOME_FRIENDS", "FRIENDS_EXCEPT" -> normalized;
            default -> "PUBLIC";
        };
    }

    public boolean canViewPost(Post post, UUID userId) {
        if (post.getAuthorId().equals(userId)) return true;
        
        return switch (post.getVisibility()) {
            case "PUBLIC", "FRIENDS" -> true; // content-service doesn't enforce friends
            case "SOME_FRIENDS" -> post.getIncludedIds() != null && post.getIncludedIds().contains(userId.toString());
            case "FRIENDS_EXCEPT" -> post.getExcludedIds() == null || !post.getExcludedIds().contains(userId.toString());
            case "PRIVATE" -> false;
            default -> false;
        };
    }

    private PostResponse toResponse(Post post) {
        return PostResponse.builder()
                .postId(post.getPostId())
                .authorId(post.getAuthorId())
                .contentText(post.getContentText())
                .mediaUrls(post.getMediaUrls())
                .visibility(post.getVisibility())
                .includedIds(post.getIncludedIds())
                .excludedIds(post.getExcludedIds())
                .likeCount(post.getLikeCount())
                .commentCount(post.getCommentCount())
                .shareCount(post.getShareCount())
                .status(post.getStatus())
                .createdAt(post.getCreatedAt())
                .updatedAt(post.getUpdatedAt())
                .build();
    }
}