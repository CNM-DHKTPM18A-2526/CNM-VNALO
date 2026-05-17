package iuh.cnm.vnalo.core_service.service.ai;

import iuh.cnm.vnalo.core_service.model.entity.ai.AiChatHistory;
import iuh.cnm.vnalo.core_service.repository.ai.AiChatHistoryRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AiHistoryService {

    private final AiChatHistoryRepository historyRepository;

    @Transactional
    public void saveMessage(UUID userId, UUID conversationId, String role, String content, String provider) {
        if (content == null) return;
        boolean exists = historyRepository.existsByUserIdAndConversationIdAndRoleAndContent(userId, conversationId, role, content.trim());
        if (exists) {
            return; // Avoid duplicating existing message entries
        }
        AiChatHistory history = AiChatHistory.builder()
                .userId(userId)
                .conversationId(conversationId)
                .role(role)
                .content(content.trim())
                .provider(provider)
                .messageType("text")
                .build();
        historyRepository.save(history);
    }

    @org.springframework.transaction.annotation.Transactional(readOnly = true)
    public java.util.List<AiChatHistory> getHistory(UUID userId, UUID conversationId) {
        return historyRepository.findByUserIdAndConversationIdOrderByCreatedAtDesc(
                userId, conversationId, org.springframework.data.domain.PageRequest.of(0, 200)
        ).getContent();
    }
}
