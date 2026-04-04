package iuh.cnm.vnalo.content_service.model.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "story_view", schema = "content")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class StoryView {

    @Id
    @GeneratedValue
    private UUID viewId;

    private UUID storyId;

    private UUID viewerId;

    private OffsetDateTime viewedAt;
}