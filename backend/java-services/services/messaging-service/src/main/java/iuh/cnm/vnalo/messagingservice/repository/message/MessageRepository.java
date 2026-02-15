package iuh.cnm.vnalo.messagingservice.repository.message;

import iuh.cnm.vnalo.messagingservice.model.entity.message.Message;
import org.springframework.data.cassandra.repository.CassandraRepository;
import org.springframework.data.cassandra.repository.Query;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Slice;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface MessageRepository extends CassandraRepository<Message, Void> {

    /**
     * Get messages for a conversation, ordered by created_at DESC (natural clustering order).
     * Uses Slice (not Page) because Cassandra doesn't support count queries efficiently.
     */
    Slice<Message> findByConversationId(UUID conversationId, Pageable pageable);

    /**
     * Find a specific message by its composite key.
     */
    @Query("SELECT * FROM message WHERE conversation_id = ?0 AND message_id = ?1 ALLOW FILTERING")
    Optional<Message> findByConversationIdAndMessageId(UUID conversationId, UUID messageId);
}
