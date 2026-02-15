package iuh.cnm.vnalo.messagingservice.model.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.UUID;

@Entity
@Table(name = "poll_option")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PollOption {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "option_id")
    private UUID optionId;

    @Column(name = "poll_id", nullable = false)
    private UUID pollId;

    @Column(name = "text", nullable = false, length = 200)
    private String text;

    @Column(name = "created_by", nullable = false)
    private UUID createdBy;

    @Column(name = "vote_count")
    @Builder.Default
    private Integer voteCount = 0;

    @Column(name = "option_order", nullable = false)
    private Integer optionOrder;
}
