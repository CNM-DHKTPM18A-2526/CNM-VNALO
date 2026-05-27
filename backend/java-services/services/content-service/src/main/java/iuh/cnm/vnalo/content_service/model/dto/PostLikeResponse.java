package iuh.cnm.vnalo.content_service.model.dto;

import lombok.Builder;
import lombok.Getter;

import java.time.OffsetDateTime;
import java.util.UUID;

@Getter
@Builder
public class PostLikeResponse {

    private UUID userId;
    private OffsetDateTime likedAt;
}
