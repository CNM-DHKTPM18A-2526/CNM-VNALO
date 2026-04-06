package iuh.cnm.vnalo.analytics_service.model.dto.response;

import lombok.Builder;
import lombok.Getter;

@Builder
@Getter
public class MessageTypeCountResponse {
    private String messageType;
    private long count;
}