package iuh.cnm.vnalo.core_service.repository.ai;

import iuh.cnm.vnalo.core_service.model.entity.ai.AiChatHistory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.UUID;

@Repository
public interface AiChatHistoryRepository extends JpaRepository<AiChatHistory, UUID> {
    Page<AiChatHistory> findByUserIdAndConversationIdOrderByCreatedAtDesc(UUID userId, UUID conversationId, Pageable pageable);

    long deleteByUserIdAndConversationId(UUID userId, UUID conversationId);

    boolean existsByUserIdAndConversationIdAndRoleAndContentAndCreatedAtBetween(
            UUID userId, UUID conversationId, String role, String content,
            OffsetDateTime minTime, OffsetDateTime maxTime
    );

    long countByCreatedAtAfter(OffsetDateTime since);

    long countByRoleAndCreatedAtAfter(String role, OffsetDateTime since);

    @Query("SELECT COUNT(DISTINCT a.userId) FROM AiChatHistory a WHERE a.createdAt >= :since")
    long countDistinctUsersSince(@Param("since") OffsetDateTime since);

    @Modifying
    @Query(value = "INSERT INTO ai_chat_history "
            + "(user_id, conversation_id, client_entry_id, role, content, provider, message_type, created_at) "
            + "VALUES (:userId, :conversationId, :clientEntryId, :role, :content, :provider, 'text', :createdAt) "
            + "ON CONFLICT (user_id, conversation_id, client_entry_id) "
            + "WHERE client_entry_id IS NOT NULL DO NOTHING",
            nativeQuery = true)
    int insertWithClientEntryIdIfAbsent(
            @Param("userId") UUID userId,
            @Param("conversationId") UUID conversationId,
            @Param("clientEntryId") String clientEntryId,
            @Param("role") String role,
            @Param("content") String content,
            @Param("provider") String provider,
            @Param("createdAt") OffsetDateTime createdAt
    );
}
