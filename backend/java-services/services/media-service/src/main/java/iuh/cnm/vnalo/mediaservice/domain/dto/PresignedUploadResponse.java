package iuh.cnm.vnalo.mediaservice.domain.dto;

import lombok.Builder;
import lombok.Data;
import java.util.UUID;

@Data
@Builder
public class PresignedUploadResponse {
    private UUID mediaId;
    private String objectKey;
    private String presignedUrl;
}
