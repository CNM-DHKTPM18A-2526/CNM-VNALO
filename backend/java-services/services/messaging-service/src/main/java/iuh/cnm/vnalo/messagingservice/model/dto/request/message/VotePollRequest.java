package iuh.cnm.vnalo.messagingservice.model.dto.request.message;

import jakarta.validation.constraints.NotEmpty;
import lombok.Data;

import java.util.List;
import java.util.UUID;

@Data
public class VotePollRequest {
    @NotEmpty(message = "Must select at least one option")
    private List<UUID> optionIds;
}
