package iuh.cnm.vnalo.messagingservice.repository.call;

import iuh.cnm.vnalo.messagingservice.model.entity.call.CallSession;
import iuh.cnm.vnalo.messagingservice.model.enums.call.CallStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface CallSessionRepository extends JpaRepository<CallSession, UUID> {
    List<CallSession> findByConversationIdOrderByStartedAtDesc(UUID conversationId);
    Optional<CallSession> findByConversationIdAndStatus(UUID conversationId, CallStatus status);
    List<CallSession> findByInitiatorIdOrderByStartedAtDesc(UUID initiatorId);
}
