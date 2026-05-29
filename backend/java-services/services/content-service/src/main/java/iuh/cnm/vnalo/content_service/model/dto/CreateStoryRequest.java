package iuh.cnm.vnalo.content_service.model.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Getter;
import lombok.Setter;

import java.util.List;

@Getter
@Setter
public class CreateStoryRequest {

    @NotBlank
    private String mediaUrl;

    private String caption;

    private String visibility;

    private List<String> includedIds;

    private List<String> excludedIds;
}