package iuh.cnm.vnalo.mediaservice.event;

import iuh.cnm.vnalo.mediaservice.domain.model.MediaCategory;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MediaUploadedEvent {
    private UUID mediaId;
    private String objectKey;
    private String bucket;
    private MediaCategory category;
}
