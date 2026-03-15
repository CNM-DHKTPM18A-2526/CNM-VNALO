package iuh.cnm.vnalo.content_service.model.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class UpdateCommentRequest {

    @NotBlank(message = "contentText must not be blank")
    @Size(max = 3000, message = "contentText must not exceed 3000 characters")
    private String contentText;
}