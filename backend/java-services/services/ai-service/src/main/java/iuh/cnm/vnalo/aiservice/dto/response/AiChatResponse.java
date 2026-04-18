package iuh.cnm.vnalo.aiservice.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.Map;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AiChatResponse {

    private String textReply;

    // The command AI wants the mobile app to execute (e.g., "START_CALL", "OPEN_STICKER")
    private String actionCommand;

    // Parameters for the command (e.g., {"targetUser": "user_123", "isVideo": true})
    private Map<String, Object> actionParams;

    // Billing/Quota limits tracking
    private int estimatedTokens;
}
