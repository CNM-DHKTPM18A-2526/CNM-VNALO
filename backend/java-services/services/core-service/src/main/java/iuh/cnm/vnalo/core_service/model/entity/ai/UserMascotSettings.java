package iuh.cnm.vnalo.core_service.model.entity.ai;

import iuh.cnm.vnalo.core_service.model.entity.base.BaseEntity;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.util.Map;
import java.util.UUID;

@Entity
@Table(name = "user_mascot_settings")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserMascotSettings extends BaseEntity {

    @Id
    @Column(name = "user_id")
    private UUID userId;

    @Column(name = "mascot_id")
    private String mascotId;

    @Column(name = "mascot_name")
    private String mascotName;

    @Column(name = "mascot_type")
    private String mascotType; // '2D' or '3D'

    @Column(name = "personality_type")
    private String personalityType;

    @Column(name = "primary_color")
    private String primaryColor;

    @Column(name = "language_code")
    private String languageCode;

    @Column(name = "custom_instructions", columnDefinition = "TEXT")
    private String customInstructions;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "metadata", columnDefinition = "jsonb")
    private Map<String, Object> metadata;

    @Builder.Default
    @Column(name = "is_active")
    private boolean isActive = true;
}
