package iuh.cnm.vnalo.messagingservice.repository.conversation;

import iuh.cnm.vnalo.messagingservice.model.entity.conversation.ConversationDirectMap;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface ConversationDirectMapRepository extends JpaRepository<ConversationDirectMap, ConversationDirectMap.DirectMapId> {
    Optional<ConversationDirectMap> findByUserId1AndUserId2(UUID userId1, UUID userId2);
}
