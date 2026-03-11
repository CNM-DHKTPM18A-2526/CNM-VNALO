package iuh.cnm.vnalo.content_service.service;

import iuh.cnm.vnalo.content_service.model.dto.CommentPageResponse;
import iuh.cnm.vnalo.content_service.model.dto.CommentResponse;
import iuh.cnm.vnalo.content_service.model.dto.CreateCommentRequest;
import iuh.cnm.vnalo.content_service.model.entity.Comment;
import iuh.cnm.vnalo.content_service.repository.CommentRepository;
import iuh.cnm.vnalo.content_service.repository.PostRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class CommentService {

    private final CommentRepository commentRepository;
    private final PostRepository postRepository;

    @Transactional
    public CommentResponse createComment(UUID postId, UUID authorId, CreateCommentRequest request) {
        boolean postExists = postRepository.existsByPostIdAndStatus(postId, "ACTIVE");
        if (!postExists) {
            throw new IllegalArgumentException("Post not found");
        }

        Comment comment = Comment.builder()
                .postId(postId)
                .authorId(authorId)
                .parentCommentId(request.getParentCommentId())
                .contentText(request.getContentText())
                .status("ACTIVE")
                .build();

        Comment saved = commentRepository.saveAndFlush(comment);
        return toResponse(saved);
    }

    @Transactional(readOnly = true)
    public CommentPageResponse getCommentsByPost(UUID postId, int page, int size) {
        int safePage = Math.max(page, 0);
        int safeSize = Math.min(Math.max(size, 1), 50);

        PageRequest pageable = PageRequest.of(
                safePage,
                safeSize,
                Sort.by(Sort.Direction.DESC, "createdAt")
        );

        Page<Comment> result = commentRepository.findByPostIdAndStatusOrderByCreatedAtDesc(
                postId,
                "ACTIVE",
                pageable
        );

        return CommentPageResponse.builder()
                .items(result.getContent().stream().map(this::toResponse).toList())
                .page(result.getNumber())
                .size(result.getSize())
                .totalElements(result.getTotalElements())
                .totalPages(result.getTotalPages())
                .last(result.isLast())
                .build();
    }

    private CommentResponse toResponse(Comment comment) {
        return CommentResponse.builder()
                .commentId(comment.getCommentId())
                .postId(comment.getPostId())
                .authorId(comment.getAuthorId())
                .parentCommentId(comment.getParentCommentId())
                .contentText(comment.getContentText())
                .likeCount(comment.getLikeCount())
                .status(comment.getStatus())
                .createdAt(comment.getCreatedAt())
                .updatedAt(comment.getUpdatedAt())
                .build();
    }
}