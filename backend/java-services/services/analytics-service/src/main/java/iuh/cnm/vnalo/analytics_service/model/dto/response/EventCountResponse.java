package iuh.cnm.vnalo.analytics_service.model.dto.response;

import lombok.AllArgsConstructor;
import lombok.Getter;

@Getter
@AllArgsConstructor
public class EventCountResponse {
    private String key;
    private long count;
}
