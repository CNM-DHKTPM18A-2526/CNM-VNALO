package iuh.cnm.vnalo.messagingservice.model.entity;

import iuh.cnm.vnalo.messagingservice.model.enums.message.PollStatus;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "poll")
@EntityListeners(AuditingEntityListener.class)
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Poll {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "poll_id")
    private UUID pollId;

    @Column(name = "conversation_id", nullable = false)
    private UUID conversationId;

    @Column(name = "message_id", nullable = false)
    private UUID messageId;

    @Column(name = "creator_id", nullable = false)
    private UUID creatorId;

    @Column(name = "question", nullable = false, columnDefinition = "TEXT")
    private String question;

    @Column(name = "allow_multiple")
    @Builder.Default
    private Boolean allowMultiple = false;

    @Column(name = "allow_add_option")
    @Builder.Default
    private Boolean allowAddOption = false;

    @Column(name = "is_anonymous")
    @Builder.Default
    private Boolean isAnonymous = false;

    @Column(name = "expires_at")
    private Instant expiresAt;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", length = 20)
    @Builder.Default
    private PollStatus status = PollStatus.ACTIVE;

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @OneToMany(mappedBy = "pollId", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<PollOption> options = new ArrayList<>();
}
