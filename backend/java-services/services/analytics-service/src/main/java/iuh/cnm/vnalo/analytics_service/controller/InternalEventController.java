package iuh.cnm.vnalo.analytics_service.controller;

import iuh.cnm.vnalo.analytics_service.model.dto.ApiResponse;
import iuh.cnm.vnalo.analytics_service.model.dto.request.AnalyticsEventRequest;
import iuh.cnm.vnalo.analytics_service.service.AnalyticsEventIngestionService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/internal/events")
@RequiredArgsConstructor
public class InternalEventController {
    private final AnalyticsEventIngestionService ingestionService;

    @PostMapping
    public ApiResponse<Map<String, UUID>> ingestEvent(
            @Valid @RequestBody AnalyticsEventRequest request
    ) {
        UUID eventId = ingestionService.ingestEvent(request);
        return ApiResponse.success("Event ingested successfully", Map.of("eventId", eventId));
    }
}