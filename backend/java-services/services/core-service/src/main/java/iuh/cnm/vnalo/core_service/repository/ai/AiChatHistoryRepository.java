package iuh.cnm.vnalo.core_service.repository.ai;

import iuh.cnm.vnalo.core_service.model.entity.ai.AiChatHistory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.UUID;

@Repository
public interface AiChatHistoryRepository extends JpaRepository<AiChatHistory, UUID> {
    Page<AiChatHistory> findByUserIdAndConversationIdOrderByCreatedAtDesc(UUID userId, UUID conversationId, Pageable pageable);
    boolean existsByUserIdAndConversationIdAndRoleAndContentAndCreatedAtBetween(
            UUID userId, UUID conversationId, String role, String content,
            java.time.OffsetDateTime minTime, java.time.OffsetDateTime maxTime
    );
}
