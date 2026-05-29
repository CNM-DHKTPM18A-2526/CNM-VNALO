package iuh.cnm.vnalo.content_service.repository;

import iuh.cnm.vnalo.content_service.model.entity.Post;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;
import java.util.UUID;

public interface PostRepository extends JpaRepository<Post, UUID> {

    @Query(value = "SELECT * FROM content.post p WHERE p.status = :status AND (" +
            " p.author_id = :userId OR " +
            " p.visibility = 'PUBLIC' OR " +
            " p.visibility = 'FRIENDS' OR " +
            " (p.visibility = 'SOME_FRIENDS' AND p.included_ids @> CAST(CONCAT('[', '\"', CAST(:userId AS text), '\"', ']') AS jsonb)) OR " +
            " (p.visibility = 'FRIENDS_EXCEPT' AND NOT (p.excluded_ids @> CAST(CONCAT('[', '\"', CAST(:userId AS text), '\"', ']') AS jsonb))) " +
            ") ORDER BY p.created_at DESC",
            countQuery = "SELECT count(*) FROM content.post p WHERE p.status = :status AND (" +
            " p.author_id = :userId OR " +
            " p.visibility = 'PUBLIC' OR " +
            " p.visibility = 'FRIENDS' OR " +
            " (p.visibility = 'SOME_FRIENDS' AND p.included_ids @> CAST(CONCAT('[', '\"', CAST(:userId AS text), '\"', ']') AS jsonb)) OR " +
            " (p.visibility = 'FRIENDS_EXCEPT' AND NOT (p.excluded_ids @> CAST(CONCAT('[', '\"', CAST(:userId AS text), '\"', ']') AS jsonb))) " +
            ")",
            nativeQuery = true)
    Page<Post> findTimelineForUser(@Param("status") String status, @Param("userId") UUID userId, Pageable pageable);

    @Query(value = "SELECT * FROM content.post p WHERE p.status = :status AND p.author_id = :targetUserId AND (" +
            " :targetUserId = :requesterId OR " +
            " p.visibility = 'PUBLIC' OR " +
            " p.visibility = 'FRIENDS' OR " +
            " (p.visibility = 'SOME_FRIENDS' AND p.included_ids @> CAST(CONCAT('[', '\"', CAST(:requesterId AS text), '\"', ']') AS jsonb)) OR " +
            " (p.visibility = 'FRIENDS_EXCEPT' AND NOT (p.excluded_ids @> CAST(CONCAT('[', '\"', CAST(:requesterId AS text), '\"', ']') AS jsonb))) " +
            ") ORDER BY p.created_at DESC",
            countQuery = "SELECT count(*) FROM content.post p WHERE p.status = :status AND p.author_id = :targetUserId AND (" +
            " :targetUserId = :requesterId OR " +
            " p.visibility = 'PUBLIC' OR " +
            " p.visibility = 'FRIENDS' OR " +
            " (p.visibility = 'SOME_FRIENDS' AND p.included_ids @> CAST(CONCAT('[', '\"', CAST(:requesterId AS text), '\"', ']') AS jsonb)) OR " +
            " (p.visibility = 'FRIENDS_EXCEPT' AND NOT (p.excluded_ids @> CAST(CONCAT('[', '\"', CAST(:requesterId AS text), '\"', ']') AS jsonb))) " +
            ")",
            nativeQuery = true)
    Page<Post> findTimelineForUserProfile(
            @Param("status") String status, 
            @Param("targetUserId") UUID targetUserId, 
            @Param("requesterId") UUID requesterId, 
            Pageable pageable
    );

    Page<Post> findByStatusOrderByCreatedAtDesc(String status, Pageable pageable);

    boolean existsByPostIdAndStatus(UUID postId, String status);

    Optional<Post> findByPostIdAndStatus(UUID postId, String status);

    Optional<Post> findByPostId(UUID postId);
}