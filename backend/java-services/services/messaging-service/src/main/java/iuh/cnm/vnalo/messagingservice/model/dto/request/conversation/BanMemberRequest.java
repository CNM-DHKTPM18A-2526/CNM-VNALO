package iuh.cnm.vnalo.messagingservice.model.dto.request.conversation;

import lombok.Data;

import java.time.Instant;

@Data
public class BanMemberRequest {
    private String reason;
    private Instant expiresAt;
}
