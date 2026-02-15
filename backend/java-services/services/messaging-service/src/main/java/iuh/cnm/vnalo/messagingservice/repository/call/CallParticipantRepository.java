package iuh.cnm.vnalo.messagingservice.repository.call;

import iuh.cnm.vnalo.messagingservice.model.entity.call.CallParticipant;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface CallParticipantRepository extends JpaRepository<CallParticipant, CallParticipant.CallParticipantId> {
    List<CallParticipant> findByCallId(UUID callId);
    Optional<CallParticipant> findByCallIdAndUserId(UUID callId, UUID userId);
    List<CallParticipant> findByUserIdOrderByJoinedAtDesc(UUID userId);
}
