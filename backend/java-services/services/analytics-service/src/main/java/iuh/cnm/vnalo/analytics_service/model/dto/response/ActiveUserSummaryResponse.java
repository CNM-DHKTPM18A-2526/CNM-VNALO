package iuh.cnm.vnalo.analytics_service.model.dto.response;

import lombok.Builder;
import lombok.Getter;

@Builder
@Getter
public class ActiveUserSummaryResponse {
    private long dau;
    private long wau;
    private long mau;
}
