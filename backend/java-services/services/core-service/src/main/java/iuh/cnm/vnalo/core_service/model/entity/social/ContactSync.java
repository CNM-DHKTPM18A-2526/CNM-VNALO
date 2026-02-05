package iuh.cnm.vnalo.core_service.model.entity.social;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

/**
 * Contact synchronization entity for storing synced phone contacts.
 * Allows users to find friends from their phone contacts.
 */
@Entity
@Table(name = "contact_sync", indexes = {
    @Index(name = "idx_contact_user", columnList = "user_id"),
    @Index(name = "idx_contact_matched", columnList = "matched_user_id")
}, uniqueConstraints = {
    @UniqueConstraint(name = "uk_contact_sync", columnNames = {"user_id", "phone_number"})
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ContactSync {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "sync_id", updatable = false, nullable = false)
    private UUID syncId;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "phone_number", nullable = false, length = 20)
    private String phoneNumber;

    @Column(name = "contact_name", length = 100)
    private String contactName;

    @Column(name = "matched_user_id")
    private UUID matchedUserId;

    @Column(name = "invited_at")
    private Instant invitedAt;

    @Column(name = "synced_at")
    @Builder.Default
    private Instant syncedAt = Instant.now();

    /**
     * Check if this contact has been matched to a registered user.
     */
    public boolean isMatched() {
        return matchedUserId != null;
    }

    /**
     * Check if an invitation has been sent to this contact.
     */
    public boolean isInvited() {
        return invitedAt != null;
    }

    /**
     * Mark this contact as invited.
     */
    public void markAsInvited() {
        this.invitedAt = Instant.now();
    }

    /**
     * Match this contact to a registered user.
     */
    public void matchToUser(UUID userId) {
        this.matchedUserId = userId;
    }
}
