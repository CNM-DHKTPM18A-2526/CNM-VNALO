package iuh.cnm.vnalo.core_service.service.ai;

import iuh.cnm.vnalo.core_service.model.entity.ai.UserMascotSettings;
import iuh.cnm.vnalo.core_service.repository.ai.UserMascotSettingsRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
@Slf4j
@RequiredArgsConstructor
public class MascotService {

    private final UserMascotSettingsRepository mascotRepository;

    public UserMascotSettings getMascotSettings(UUID userId) {
        return mascotRepository.findByUserId(userId)
                .orElseGet(() -> createDefaultSettings(userId));
    }

    @Transactional
    public UserMascotSettings updateMascotSettings(UUID userId, UserMascotSettings newSettings) {
        UserMascotSettings existing = mascotRepository.findByUserId(userId)
                .orElseGet(() -> createDefaultSettings(userId));

        // Only update allowed fields
        if (newSettings.getMascotId() != null) existing.setMascotId(newSettings.getMascotId());
        if (newSettings.getMascotName() != null) existing.setMascotName(newSettings.getMascotName());
        if (newSettings.getMascotType() != null) existing.setMascotType(newSettings.getMascotType());
        if (newSettings.getPersonalityType() != null) existing.setPersonalityType(newSettings.getPersonalityType());
        if (newSettings.getPrimaryColor() != null) existing.setPrimaryColor(newSettings.getPrimaryColor());
        if (newSettings.getLanguageCode() != null) existing.setLanguageCode(newSettings.getLanguageCode());
        if (newSettings.getCustomInstructions() != null) existing.setCustomInstructions(newSettings.getCustomInstructions());
        if (newSettings.getMetadata() != null) existing.setMetadata(newSettings.getMetadata());

        log.info("Updated mascot settings for user: {}", userId);
        return mascotRepository.save(existing);
    }

    private UserMascotSettings createDefaultSettings(UUID userId) {
        UserMascotSettings defaultSettings = UserMascotSettings.builder()
                .userId(userId)
                .mascotId("default_mascot")
                .mascotName("VNALO AI")
                .mascotType("2D")
                .personalityType("friendly")
                .primaryColor("#4A90E2")
                .languageCode("vi")
                .isActive(true)
                .build();
        return mascotRepository.save(defaultSettings);
    }
}
