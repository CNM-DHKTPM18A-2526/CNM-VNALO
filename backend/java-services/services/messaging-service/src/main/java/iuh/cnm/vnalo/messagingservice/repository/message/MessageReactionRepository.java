package iuh.cnm.vnalo.messagingservice.repository.message;

import iuh.cnm.vnalo.messagingservice.model.entity.MessageReaction;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface MessageReactionRepository extends JpaRepository<MessageReaction, UUID> {
    List<MessageReaction> findByMessageId(UUID messageId);
    Optional<MessageReaction> findByMessageIdAndUserId(UUID messageId, UUID userId);
    boolean existsByMessageIdAndUserId(UUID messageId, UUID userId);
    void deleteByMessageIdAndUserId(UUID messageId, UUID userId);
}
