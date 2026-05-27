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
                .status("ACTIVE")
                .build();

        Post saved = postRepository.saveAndFlush(post);
        return toResponse(saved);
    }

    @Transactional(readOnly = true)
    public TimelineResponse getTimeline(int page, int size) {
        int safePage = Math.max(page, 0);
        int safeSize = Math.min(Math.max(size, 1), 50);

        PageRequest pageable = PageRequest.of(
                safePage,
                safeSize,
                Sort.by(Sort.Direction.DESC, "createdAt")
        );

        Page<Post> result = postRepository.findByStatusOrderByCreatedAtDesc("ACTIVE", pageable);

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
    public PostResponse getPostById(UUID postId) {
        Post post = postRepository.findByPostIdAndStatus(postId, "ACTIVE")
                .orElseThrow(() -> new ApiException(ErrorCode.POST_NOT_FOUND));

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

    private String normalizeVisibility(String visibility) {
        if (visibility == null || visibility.isBlank()) {
            return "PUBLIC";
        }

        String normalized = visibility.trim().toUpperCase(Locale.ROOT);
        return switch (normalized) {
            case "PUBLIC", "FRIENDS", "PRIVATE" -> normalized;
            default -> "PUBLIC";
        };
    }

    private PostResponse toResponse(Post post) {
        return PostResponse.builder()
                .postId(post.getPostId())
                .authorId(post.getAuthorId())
                .contentText(post.getContentText())
                .mediaUrls(post.getMediaUrls())
                .visibility(post.getVisibility())
                .likeCount(post.getLikeCount())
                .commentCount(post.getCommentCount())
                .shareCount(post.getShareCount())
                .status(post.getStatus())
                .createdAt(post.getCreatedAt())
                .updatedAt(post.getUpdatedAt())
                .build();
    }
}