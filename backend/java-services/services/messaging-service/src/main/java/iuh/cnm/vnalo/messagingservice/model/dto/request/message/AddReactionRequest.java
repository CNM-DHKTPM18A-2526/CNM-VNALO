package iuh.cnm.vnalo.messagingservice.model.dto.request.message;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.util.UUID;

@Data
public class AddReactionRequest {

    @NotNull(message = "Message ID is required")
    private UUID messageId;

    @NotBlank(message = "Emoji is required")
    private String emoji;
}
