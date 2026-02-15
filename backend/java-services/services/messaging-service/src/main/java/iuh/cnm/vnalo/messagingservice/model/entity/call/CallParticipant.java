package iuh.cnm.vnalo.messagingservice.model.entity.call;

import iuh.cnm.vnalo.messagingservice.model.enums.call.CallParticipantRole;
import iuh.cnm.vnalo.messagingservice.model.enums.call.CallParticipantStatus;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.io.Serializable;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "call_participant")
@IdClass(CallParticipant.CallParticipantId.class)
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CallParticipant {

    @Id
    @Column(name = "call_id")
    private UUID callId;

    @Id
    @Column(name = "user_id")
    private UUID userId;

    @Enumerated(EnumType.STRING)
    @Column(name = "role", length = 20)
    @Builder.Default
    private CallParticipantRole role = CallParticipantRole.CALLEE;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", length = 20)
    @Builder.Default
    private CallParticipantStatus status = CallParticipantStatus.RINGING;

    @Column(name = "joined_at")
    private Instant joinedAt;

    @Column(name = "left_at")
    private Instant leftAt;

    @Column(name = "is_video_enabled")
    @Builder.Default
    private Boolean isVideoEnabled = false;

    @Column(name = "is_audio_enabled")
    @Builder.Default
    private Boolean isAudioEnabled = true;

    @Column(name = "is_screen_sharing")
    @Builder.Default
    private Boolean isScreenSharing = false;

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class CallParticipantId implements Serializable {
        private UUID callId;
        private UUID userId;
    }
}
