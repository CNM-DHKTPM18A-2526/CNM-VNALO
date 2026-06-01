package iuh.cnm.vnalo.content_service.service;

import iuh.cnm.vnalo.content_service.exception.ApiException;
import iuh.cnm.vnalo.content_service.exception.ErrorCode;
import iuh.cnm.vnalo.content_service.model.dto.PostLikeResponse;
import iuh.cnm.vnalo.content_service.model.entity.Post;
import iuh.cnm.vnalo.content_service.model.entity.PostLike;
import iuh.cnm.vnalo.content_service.repository.PostLikeRepository;
import iuh.cnm.vnalo.content_service.repository.PostRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class LikeService {

    private final PostRepository postRepository;
    private final PostLikeRepository postLikeRepository;
    private final PostService postService;

    @Transactional
    public void likePost(UUID postId, UUID userId, String reactionType) {
        Post post = postRepository.findByPostIdAndStatus(postId, "ACTIVE")
                .orElseThrow(() -> new ApiException(ErrorCode.POST_NOT_FOUND));

        if (!postService.canViewPost(post, userId)) {
            throw new ApiException(ErrorCode.FORBIDDEN);
        }

        String normalizedReaction = reactionType == null || reactionType.isBlank()
                ? "LOVE"
                : reactionType.trim().toUpperCase();

        postLikeRepository.findByPostIdAndUserId(postId, userId).ifPresentOrElse(
                existing -> {
                    existing.setReactionType(normalizedReaction);
                    postLikeRepository.save(existing);
                },
                () -> {
                    PostLike postLike = PostLike.builder()
                            .postId(postId)
                            .userId(userId)
                            .reactionType(normalizedReaction)
                            .build();

                    postLikeRepository.save(postLike);
                    post.setLikeCount(post.getLikeCount() + 1);
                    postRepository.save(post);

                }
        );
    }

    @Transactional
    public void unlikePost(UUID postId, UUID userId) {
        Post post = postRepository.findByPostIdAndStatus(postId, "ACTIVE")
                .orElseThrow(() -> new ApiException(ErrorCode.POST_NOT_FOUND));

        if (!postService.canViewPost(post, userId)) {
            throw new ApiException(ErrorCode.FORBIDDEN);
        }

        postLikeRepository.findByPostIdAndUserId(postId, userId).ifPresent(postLike -> {
            postLikeRepository.delete(postLike);
            post.setLikeCount(Math.max(0, post.getLikeCount() - 1));
            postRepository.save(post);
        });
    }

    @Transactional(readOnly = true)
    public List<PostLikeResponse> getPostLikers(UUID postId, UUID userId) {
        Post post = postRepository.findByPostIdAndStatus(postId, "ACTIVE")
                .orElseThrow(() -> new ApiException(ErrorCode.POST_NOT_FOUND));

        if (!postService.canViewPost(post, userId)) {
            throw new ApiException(ErrorCode.FORBIDDEN);
        }

        return postLikeRepository.findByPostIdOrderByCreatedAtDesc(postId)
                .stream()
                .map(postLike -> PostLikeResponse.builder()
                        .userId(postLike.getUserId())
                        .reactionType(postLike.getReactionType())
                        .likedAt(postLike.getCreatedAt())
                        .build())
                .toList();
    }
}
