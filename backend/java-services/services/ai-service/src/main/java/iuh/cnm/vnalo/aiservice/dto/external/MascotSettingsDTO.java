package iuh.cnm.vnalo.aiservice.dto.external;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.Map;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MascotSettingsDTO {
    private String mascotId;
    private String mascotName;
    private String mascotType;
    private String personalityType;
    private String primaryColor;
    private String languageCode;
    private String customInstructions;
    private Map<String, Object> metadata;
}
