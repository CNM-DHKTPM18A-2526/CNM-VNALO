package iuh.cnm.vnalo.messagingservice.model.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.io.Serializable;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "poll_vote")
@IdClass(PollVote.PollVoteId.class)
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PollVote {

    @Id
    @Column(name = "poll_id")
    private UUID pollId;

    @Id
    @Column(name = "option_id")
    private UUID optionId;

    @Id
    @Column(name = "user_id")
    private UUID userId;

    @Column(name = "voted_at")
    @Builder.Default
    private Instant votedAt = Instant.now();

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class PollVoteId implements Serializable {
        private UUID pollId;
        private UUID optionId;
        private UUID userId;
    }
}
