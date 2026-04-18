package iuh.cnm.vnalo.aiservice.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

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
}
