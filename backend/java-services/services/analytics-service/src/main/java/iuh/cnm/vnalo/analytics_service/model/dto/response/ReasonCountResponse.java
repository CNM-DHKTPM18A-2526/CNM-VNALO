package iuh.cnm.vnalo.analytics_service.model.dto.response;

import lombok.Builder;
import lombok.Getter;

@Builder
@Getter
public class ReasonCountResponse {
    private String key;
    private long value;
}