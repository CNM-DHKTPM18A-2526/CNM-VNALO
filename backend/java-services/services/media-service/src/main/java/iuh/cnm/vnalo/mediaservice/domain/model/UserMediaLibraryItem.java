package iuh.cnm.vnalo.mediaservice.domain.model;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "user_media_library_item", indexes = {
        @Index(name = "idx_user_media_lib", columnList = "user_id, saved_at DESC")
},
uniqueConstraints = {
        @UniqueConstraint(name = "unique_user_media", columnNames = {"user_id", "media_id"})
})
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserMediaLibraryItem {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "user_media_lib_id")
    private UUID userMediaLibId;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "media_id", nullable = false)
    private UUID mediaId;

    @CreationTimestamp
    @Column(name = "saved_at", updatable = false)
    private LocalDateTime savedAt;

    @Column(name = "source_type", length = 30)
    private String sourceType;  // CHAT, STORY, TIMELINE, UPLOAD

    @Column(name = "source_id")
    private UUID sourceId;
}
