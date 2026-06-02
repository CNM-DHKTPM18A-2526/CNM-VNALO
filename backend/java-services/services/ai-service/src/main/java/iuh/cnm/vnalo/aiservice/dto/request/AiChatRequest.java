package iuh.cnm.vnalo.aiservice.dto.request;

import iuh.cnm.vnalo.aiservice.dto.Message;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AiChatRequest {

    @NotBlank(message = "Prompt content cannot be empty")
    private String prompt;

    // Optional: Context of the current screen or chat room to help AI understand
    private String contextId;

    // Optional: If true, the system will instruct Gemini to reply with a structured JSON Command
    @Builder.Default
    private boolean analyzeIntent = false;

    // Deep Alignment: Structured history instead of prompt hacking
    @Size(max = 50, message = "History cannot exceed 50 messages")
    @jakarta.validation.Valid
    private List<@jakarta.validation.constraints.NotNull Message> history;

    // Deep Alignment: Flag for detailed analysis
    @Builder.Default
    private boolean enableDeepSummary = false;

    // Deep Alignment: Sync mascot preference
    private String mascotId;

    // Optional: WEB, MOBILE, DESKTOP. Used to constrain action capabilities safely.
    @Size(max = 24, message = "Client platform cannot exceed 24 characters")
    private String clientPlatform;

    // Stable client-generated ids for idempotent mobile history sync.
    @Size(max = 100, message = "Client user entry id cannot exceed 100 characters")
    private String clientUserEntryId;

    @Size(max = 100, message = "Client assistant entry id cannot exceed 100 characters")
    private String clientAssistantEntryId;
}
