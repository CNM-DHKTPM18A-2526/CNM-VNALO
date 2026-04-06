package iuh.cnm.vnalo.analytics_service.model.dto.response;

import lombok.Builder;
import lombok.Getter;

import java.util.UUID;

@Builder
@Getter
public class TopActiveUserResponse {
    private UUID userId;
    private String displayName;
    private long messageCount;
}
