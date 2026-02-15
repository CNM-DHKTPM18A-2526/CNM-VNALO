package iuh.cnm.vnalo.messagingservice.repository.message;

import iuh.cnm.vnalo.messagingservice.model.entity.PollVote;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface PollVoteRepository extends JpaRepository<PollVote, PollVote.PollVoteId> {
    boolean existsByPollIdAndUserId(UUID pollId, UUID userId);
    List<PollVote> findByPollId(UUID pollId);
    void deleteByPollIdAndUserId(UUID pollId, UUID userId);
}
