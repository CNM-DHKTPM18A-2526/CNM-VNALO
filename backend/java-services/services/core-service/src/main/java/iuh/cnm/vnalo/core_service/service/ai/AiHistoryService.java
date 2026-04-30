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
        AiChatHistory history = AiChatHistory.builder()
                .userId(userId)
                .conversationId(conversationId)
                .role(role)
                .content(content)
                .provider(provider)
                .messageType("text")
                .build();
        historyRepository.save(history);
    }
}
