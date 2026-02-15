package iuh.cnm.vnalo.messagingservice.model.dto.request.conversation;

import jakarta.validation.constraints.NotEmpty;
import lombok.Data;

import java.util.List;
import java.util.UUID;

@Data
public class AddMemberRequest {

    @NotEmpty(message = "At least one user ID is required")
    private List<UUID> userIds;
}
