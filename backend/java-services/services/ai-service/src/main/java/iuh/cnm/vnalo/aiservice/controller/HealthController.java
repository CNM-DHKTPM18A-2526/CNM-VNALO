package iuh.cnm.vnalo.aiservice.controller;

import iuh.cnm.vnalo.aiservice.dto.ApiResponse;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.Map;

@RestController
public class HealthController {

    @GetMapping("/health")
    public ResponseEntity<ApiResponse<Map<String, Object>>> health() {
        return ResponseEntity.ok(ApiResponse.ok(Map.of(
                "service", "ai-service",
                "status", "UP",
                "timestamp", Instant.now().toString()
        )));
    }
}
