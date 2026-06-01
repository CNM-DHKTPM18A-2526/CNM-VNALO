package iuh.cnm.vnalo.core_service.controller;

import iuh.cnm.vnalo.core_service.exception.ApiException;
import iuh.cnm.vnalo.core_service.exception.ErrorCode;
import iuh.cnm.vnalo.core_service.model.dto.response.ApiResponse;
import iuh.cnm.vnalo.core_service.model.dto.response.admin.AdminMonitoringEventResponse;
import iuh.cnm.vnalo.core_service.model.dto.response.admin.AdminMonitoringSummaryResponse;
import iuh.cnm.vnalo.core_service.security.UserPrincipal;
import iuh.cnm.vnalo.core_service.service.admin.AdminMonitoringService;
import io.swagger.v3.oas.annotations.Operation;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/admin/monitoring")
@RequiredArgsConstructor
public class AdminMonitoringController {
    private final AdminMonitoringService adminMonitoringService;

    @GetMapping("/summary")
    @Operation(summary = "Monitoring summary", description = "Authenticated monitoring summary with metadata-only counters")
    public ResponseEntity<ApiResponse<AdminMonitoringSummaryResponse>> getSummary(
            @AuthenticationPrincipal UserPrincipal currentUser,
            @RequestParam(defaultValue = "24") Integer windowHours
    ) {
        return ResponseEntity.ok(ApiResponse.success(
                "Monitoring summary retrieved",
                adminMonitoringService.getSummary(resolveUserId(currentUser), windowHours)
        ));
    }

    @GetMapping("/events")
    @Operation(summary = "Recent monitoring events", description = "Authenticated recent session and security events")
    public ResponseEntity<ApiResponse<List<AdminMonitoringEventResponse>>> getRecentEvents(
            @AuthenticationPrincipal UserPrincipal currentUser,
            @RequestParam(defaultValue = "12") int limit,
            @RequestParam(defaultValue = "24") Integer windowHours,
            @RequestParam(required = false) String eventType,
            @RequestParam(required = false) String platform
    ) {
        return ResponseEntity.ok(ApiResponse.success(
                "Monitoring events retrieved",
                adminMonitoringService.getRecentEvents(resolveUserId(currentUser), limit, windowHours, eventType, platform)
        ));
    }

    private java.util.UUID resolveUserId(UserPrincipal currentUser) {
        if (currentUser == null) {
            throw new ApiException(ErrorCode.UNAUTHORIZED, "Authentication is required");
        }
        return currentUser.getId();
    }
}
