package iuh.cnm.vnalo.aiservice.dto.request;

import iuh.cnm.vnalo.aiservice.dto.Message;
import jakarta.validation.constraints.NotBlank;
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
    private List<Message> history;

    // Deep Alignment: Flag for detailed analysis
    @Builder.Default
    private boolean enableDeepSummary = false;

    // Deep Alignment: Sync mascot preference
    private String mascotId;
}
