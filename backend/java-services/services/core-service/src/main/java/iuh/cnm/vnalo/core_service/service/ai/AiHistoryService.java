package iuh.cnm.vnalo.core_service.service.ai;

import iuh.cnm.vnalo.core_service.model.entity.ai.AiChatHistory;
import iuh.cnm.vnalo.core_service.repository.ai.AiChatHistoryRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AiHistoryService {

    private static final int CLIENT_ENTRY_ID_MAX_LENGTH = 100;

    private final AiChatHistoryRepository historyRepository;

    @Transactional
    public void saveMessage(UUID userId, UUID conversationId, String role, String content, String provider,
                            OffsetDateTime createdAt, String clientEntryId) {
        if (userId == null || conversationId == null || role == null || role.isBlank()) return;
        if (content == null) return;
        String normalizedContent = content.trim();
        if (normalizedContent.isEmpty()) return;
        String normalizedRole = role.trim();

        String normalizedClientEntryId = normalizeClientEntryId(clientEntryId);

        OffsetDateTime stableCreatedAt = createdAt != null ? createdAt : OffsetDateTime.now(ZoneOffset.UTC);
        if (normalizedClientEntryId != null) {
            historyRepository.insertWithClientEntryIdIfAbsent(
                    userId,
                    conversationId,
                    normalizedClientEntryId,
                    normalizedRole,
                    normalizedContent,
                    provider,
                    stableCreatedAt
            );
            return;
        }

        OffsetDateTime minTime = stableCreatedAt.minusSeconds(2);
        OffsetDateTime maxTime = stableCreatedAt.plusSeconds(2);
        boolean exists = historyRepository.existsByUserIdAndConversationIdAndRoleAndContentAndCreatedAtBetween(
                userId, conversationId, normalizedRole, normalizedContent, minTime, maxTime
        );
        if (exists) {
            return;
        }

        AiChatHistory history = AiChatHistory.builder()
                .userId(userId)
                .conversationId(conversationId)
                .clientEntryId(normalizedClientEntryId)
                .role(normalizedRole)
                .content(normalizedContent)
                .provider(provider)
                .messageType("text")
                .createdAt(stableCreatedAt)
                .build();
        historyRepository.save(history);
    }

    private String normalizeClientEntryId(String clientEntryId) {
        if (clientEntryId == null || clientEntryId.isBlank()) {
            return null;
        }
        String trimmed = clientEntryId.trim();
        return trimmed.length() <= CLIENT_ENTRY_ID_MAX_LENGTH ? trimmed : null;
    }

    @org.springframework.transaction.annotation.Transactional(readOnly = true)
    public java.util.List<AiChatHistory> getHistory(UUID userId, UUID conversationId) {
        return historyRepository.findByUserIdAndConversationIdOrderByCreatedAtDesc(
                userId, conversationId, org.springframework.data.domain.PageRequest.of(0, 200)
        ).getContent();
    }
}
