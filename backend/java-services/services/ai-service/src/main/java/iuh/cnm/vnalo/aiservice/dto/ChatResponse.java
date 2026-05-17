package iuh.cnm.vnalo.aiservice.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class ChatResponse {
    private String answer;
    private String conversationId;
    private String provider;
    private String timestamp;
    private String userEntryId;
    private String assistantEntryId;
}
