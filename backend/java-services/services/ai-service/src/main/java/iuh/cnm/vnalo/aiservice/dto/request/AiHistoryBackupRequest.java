package iuh.cnm.vnalo.aiservice.dto.request;

import iuh.cnm.vnalo.aiservice.dto.Message;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AiHistoryBackupRequest {
    
    @NotBlank(message = "Conversation ID is required")
    private String conversationId;
    
    @NotEmpty(message = "History entries cannot be empty")
    private List<Message> entries;
}
