package iuh.cnm.vnalo.content_service.repository;

import iuh.cnm.vnalo.content_service.model.entity.Comment;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface CommentRepository extends JpaRepository<Comment, UUID> {

    Page<Comment> findByPostIdAndStatusOrderByCreatedAtDesc(UUID postId, String status, Pageable pageable);

    Optional<Comment> findByCommentIdAndStatus(UUID commentId, String status);
}