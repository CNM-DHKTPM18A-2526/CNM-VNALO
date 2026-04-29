package iuh.cnm.vnalo.core_service.controller.ai;

import iuh.cnm.vnalo.core_service.model.entity.ai.UserMascotSettings;
import iuh.cnm.vnalo.core_service.service.ai.MascotService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/ai/mascot")
@RequiredArgsConstructor
public class MascotController {

    private final MascotService mascotService;

    @GetMapping
    public ResponseEntity<UserMascotSettings> getMyMascot(@AuthenticationPrincipal UserDetails userDetails) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(mascotService.getMascotSettings(userId));
    }

    @GetMapping("/internal/settings")
    public ResponseEntity<UserMascotSettings> getInternalSettings(@RequestParam UUID userId) {
        return ResponseEntity.ok(mascotService.getMascotSettings(userId));
    }

    @PutMapping
    public ResponseEntity<UserMascotSettings> updateMyMascot(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody UserMascotSettings settings) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(mascotService.updateMascotSettings(userId, settings));
    }
}
