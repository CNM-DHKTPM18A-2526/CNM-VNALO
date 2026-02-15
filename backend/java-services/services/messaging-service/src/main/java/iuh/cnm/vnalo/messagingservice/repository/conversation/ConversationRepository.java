package iuh.cnm.vnalo.messagingservice.repository.conversation;

import iuh.cnm.vnalo.messagingservice.model.entity.conversation.Conversation;
import iuh.cnm.vnalo.messagingservice.model.enums.conversation.ConversationStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface ConversationRepository extends JpaRepository<Conversation, UUID> {
    List<Conversation> findByCreatedByAndStatus(UUID createdBy, ConversationStatus status);
}
