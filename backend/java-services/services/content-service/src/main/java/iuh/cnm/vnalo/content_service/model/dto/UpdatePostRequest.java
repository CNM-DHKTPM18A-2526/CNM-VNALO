package iuh.cnm.vnalo.content_service.model.dto;

import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.Setter;

import java.util.List;

@Getter
@Setter
public class UpdatePostRequest {

    @Size(max = 5000, message = "contentText must not exceed 5000 characters")
    private String contentText;

    private List<String> mediaUrls;

    /**
     * Allowed values:
     * PUBLIC, FRIENDS, PRIVATE
     */
    private String visibility;

    private List<String> includedIds;

    private List<String> excludedIds;
}