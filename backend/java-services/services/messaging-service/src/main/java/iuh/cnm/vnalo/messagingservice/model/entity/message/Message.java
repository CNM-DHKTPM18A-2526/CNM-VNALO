package iuh.cnm.vnalo.messagingservice.model.entity.message;

import iuh.cnm.vnalo.messagingservice.model.enums.message.MessageStatus;
import iuh.cnm.vnalo.messagingservice.model.enums.message.MessageType;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.cassandra.core.cql.Ordering;
import org.springframework.data.cassandra.core.cql.PrimaryKeyType;
import org.springframework.data.cassandra.core.mapping.Column;
import org.springframework.data.cassandra.core.mapping.PrimaryKeyColumn;
import org.springframework.data.cassandra.core.mapping.Table;

import java.time.Instant;
import java.util.UUID;

/**
 * Cassandra Message entity.
 * Partition key: conversation_id (all messages in a conversation are co-located)
 * Clustering: created_at DESC, message_id DESC (latest messages first)
 */
@Table("message")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Message {

    @PrimaryKeyColumn(name = "conversation_id", ordinal = 0, type = PrimaryKeyType.PARTITIONED)
    private UUID conversationId;

    @PrimaryKeyColumn(name = "created_at", ordinal = 1, type = PrimaryKeyType.CLUSTERED, ordering = Ordering.DESCENDING)
    @Builder.Default
    private Instant createdAt = Instant.now();

    @PrimaryKeyColumn(name = "message_id", ordinal = 2, type = PrimaryKeyType.CLUSTERED, ordering = Ordering.DESCENDING)
    @Builder.Default
    private UUID messageId = UUID.randomUUID();

    @Column("sender_id")
    private UUID senderId;

    @Column("type")
    private String type; // MessageType enum name

    @Column("content")
    private String content;

    @Column("reply_to_message_id")
    private UUID replyToMessageId;

    @Column("attachments")
    private String attachments;

    @Column("status")
    @Builder.Default
    private String status = "SENT"; // MessageStatus enum name

    @Column("is_deleted")
    @Builder.Default
    private Boolean isDeleted = false;

    // Convenience methods for enum conversion
    public MessageType getTypeEnum() {
        return type != null ? MessageType.valueOf(type) : null;
    }

    public void setTypeEnum(MessageType messageType) {
        this.type = messageType != null ? messageType.name() : null;
    }

    public MessageStatus getStatusEnum() {
        return status != null ? MessageStatus.valueOf(status) : null;
    }

    public void setStatusEnum(MessageStatus messageStatus) {
        this.status = messageStatus != null ? messageStatus.name() : null;
    }
}
