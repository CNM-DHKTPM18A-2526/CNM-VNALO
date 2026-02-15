package iuh.cnm.vnalo.messagingservice.repository.conversation;

import iuh.cnm.vnalo.messagingservice.model.entity.conversation.ConversationInbox;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface ConversationInboxRepository extends JpaRepository<ConversationInbox, ConversationInbox.InboxId> {
    List<ConversationInbox> findByUserIdAndIsHiddenFalseOrderByLastMessageAtDesc(UUID userId);
}
