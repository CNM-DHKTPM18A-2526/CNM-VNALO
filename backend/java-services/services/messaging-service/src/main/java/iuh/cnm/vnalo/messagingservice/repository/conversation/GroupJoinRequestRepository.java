package iuh.cnm.vnalo.messagingservice.repository.conversation;

import iuh.cnm.vnalo.messagingservice.model.entity.conversation.GroupJoinRequest;
import iuh.cnm.vnalo.messagingservice.model.enums.conversation.JoinRequestStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface GroupJoinRequestRepository extends JpaRepository<GroupJoinRequest, UUID> {
    List<GroupJoinRequest> findByConversationIdAndStatus(UUID conversationId, JoinRequestStatus status);
    Optional<GroupJoinRequest> findByConversationIdAndUserIdAndStatus(UUID conversationId, UUID userId, JoinRequestStatus status);
    boolean existsByConversationIdAndUserIdAndStatus(UUID conversationId, UUID userId, JoinRequestStatus status);
}
