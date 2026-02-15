package iuh.cnm.vnalo.messagingservice.model.dto.request.message;

import jakarta.validation.constraints.Future;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;

@Data
public class CreatePollRequest {
    @NotBlank(message = "Question cannot be empty")
    private String question;

    @NotEmpty(message = "Options cannot be empty")
    @Size(min = 2, message = "At least 2 options are required")
    private List<String> options;

    private Boolean allowMultipleVotes = false;

    @Future(message = "Expiration date must be in the future")
    private LocalDateTime expiresAt;
}
