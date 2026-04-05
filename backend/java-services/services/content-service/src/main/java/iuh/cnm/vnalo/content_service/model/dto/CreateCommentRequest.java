package iuh.cnm.vnalo.content_service.model.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.Setter;

import java.util.UUID;

@Getter
@Setter
public class CreateCommentRequest {

    @NotBlank(message = "contentText must not be blank")
    @Size(max = 3000, message = "contentText must not exceed 3000 characters")
    private String contentText;

    /**
     * null nếu là comment gốc của post
     * có giá trị nếu là reply vào 1 comment khác
     */
    private UUID parentCommentId;
}