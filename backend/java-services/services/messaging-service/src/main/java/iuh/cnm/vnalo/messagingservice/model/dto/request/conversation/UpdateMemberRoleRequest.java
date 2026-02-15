package iuh.cnm.vnalo.messagingservice.model.dto.request.conversation;

import iuh.cnm.vnalo.messagingservice.model.enums.conversation.MemberRole;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class UpdateMemberRoleRequest {
    @NotNull(message = "Role is required")
    private MemberRole role;
}
