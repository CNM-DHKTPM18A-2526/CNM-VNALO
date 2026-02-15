package iuh.cnm.vnalo.messagingservice.model.dto.request.conversation;

import iuh.cnm.vnalo.messagingservice.model.enums.conversation.JoinMode;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class UpdateConversationRequest {

    @Size(max = 100, message = "Title must not exceed 100 characters")
    private String title;

    private String avatarUrl;

    @Size(max = 500, message = "Description must not exceed 500 characters")
    private String description;

    private JoinMode joinMode;

    private Integer memberLimit;

    private Boolean allowMemberInvite;
    private Boolean allowMemberPin;
    private Boolean allowMemberEditInfo;
}
