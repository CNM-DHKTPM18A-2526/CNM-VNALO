package iuh.cnm.vnalo.content_service.service;

import iuh.cnm.vnalo.content_service.exception.ApiException;
import iuh.cnm.vnalo.content_service.exception.ErrorCode;
import iuh.cnm.vnalo.content_service.model.entity.Post;
import iuh.cnm.vnalo.content_service.model.entity.PostLike;
import iuh.cnm.vnalo.content_service.repository.PostLikeRepository;
import iuh.cnm.vnalo.content_service.repository.PostRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class LikeService {

    private final PostRepository postRepository;
    private final PostLikeRepository postLikeRepository;

    @Transactional
    public void likePost(UUID postId, UUID userId) {
        Post post = postRepository.findByPostIdAndStatus(postId, "ACTIVE")
                .orElseThrow(() -> new ApiException(ErrorCode.POST_NOT_FOUND));

        if (postLikeRepository.existsByPostIdAndUserId(postId, userId)) {
            return;
        }

        PostLike postLike = PostLike.builder()
                .postId(postId)
                .userId(userId)
                .build();

        postLikeRepository.save(postLike);
        post.setLikeCount(post.getLikeCount() + 1);
        postRepository.save(post);
    }

    @Transactional
    public void unlikePost(UUID postId, UUID userId) {
        Post post = postRepository.findByPostIdAndStatus(postId, "ACTIVE")
                .orElseThrow(() -> new ApiException(ErrorCode.POST_NOT_FOUND));

        postLikeRepository.findByPostIdAndUserId(postId, userId).ifPresent(postLike -> {
            postLikeRepository.delete(postLike);
            post.setLikeCount(Math.max(0, post.getLikeCount() - 1));
            postRepository.save(post);
        });
    }
}