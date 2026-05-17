package iuh.cnm.vnalo.aiservice.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class Message {
    @NotNull(message = "Role is required")
    @Pattern(regexp = "^(user|assistant)$", message = "Role must be 'user' or 'assistant'")
    private String role;

    @NotNull(message = "Content is required")
    @NotBlank(message = "Content cannot be blank")
    private String content;

    private String provider;

    public Message(String role, String content) {
        this.role = role;
        this.content = content;
    }
}
