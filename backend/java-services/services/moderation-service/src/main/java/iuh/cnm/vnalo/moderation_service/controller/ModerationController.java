package iuh.cnm.vnalo.moderation_service.controller;

import iuh.cnm.vnalo.moderation_service.dto.ReportDTO;
import iuh.cnm.vnalo.moderation_service.dto.ReportDetailDTO;
import iuh.cnm.vnalo.moderation_service.dto.ReportFilter;
import iuh.cnm.vnalo.moderation_service.model.dto.request.AssignCaseRequest;
import iuh.cnm.vnalo.moderation_service.model.dto.request.CreateModerationActionRequest;
import iuh.cnm.vnalo.moderation_service.model.dto.request.ResolveCaseRequest;
import iuh.cnm.vnalo.moderation_service.model.dto.request.CreateAppealRequest;
import iuh.cnm.vnalo.moderation_service.model.dto.request.ResolveAppealRequest;
import iuh.cnm.vnalo.moderation_service.model.dto.response.ApiResponse;
import iuh.cnm.vnalo.moderation_service.model.dto.response.AppealResponse;
import iuh.cnm.vnalo.moderation_service.exception.ApiException;
import iuh.cnm.vnalo.moderation_service.exception.ErrorCode;
import iuh.cnm.vnalo.moderation_service.model.enums.ReportStatus;
import iuh.cnm.vnalo.moderation_service.model.enums.ReportTargetType;
import iuh.cnm.vnalo.moderation_service.security.ModerationPrincipal;
import iuh.cnm.vnalo.moderation_service.security.ModeratorGuardService;
import iuh.cnm.vnalo.moderation_service.service.ModerationActionService;
import iuh.cnm.vnalo.moderation_service.service.ModerationCaseService;
import iuh.cnm.vnalo.moderation_service.service.ReportService;
import iuh.cnm.vnalo.moderation_service.service.AppealService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.PageRequest;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/moderation")
@RequiredArgsConstructor
public class ModerationController {
    private final ModeratorGuardService moderatorGuardService;
    private final ReportService reportService;
    private final ModerationCaseService moderationCaseService;
    private final ModerationActionService moderationActionService;
    private final AppealService appealService;

    @GetMapping("/reports")
    public ApiResponse<Page<ReportDTO>> getReports(
                        Authentication authentication,
            @RequestParam(required = false) ReportStatus status,
            @RequestParam(required = false) ReportTargetType targetType,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
                UUID currentUserId = resolveCurrentUserId(authentication);
                moderatorGuardService.requireModerator(currentUserId);

        ReportFilter filter = ReportFilter.builder()
                .status(status)
                .targetType(targetType)
                .build();

        Pageable pageable = PageRequest.of(page, size);

        return ApiResponse.success("Fetched reports successfully",
                reportService.getReports(filter, pageable));
    }

    @GetMapping("/reports/{reportId}")
    public ApiResponse<ReportDetailDTO> getReportDetail(
                        Authentication authentication,
            @PathVariable UUID reportId
    ) {
                UUID currentUserId = resolveCurrentUserId(authentication);
                moderatorGuardService.requireModerator(currentUserId);
        return ApiResponse.success("Fetched report detail successfully",
                reportService.getReportDetail(reportId));
    }

    @PostMapping("/reports/{reportId}/assign")
    public ApiResponse<Void> assignCase(
                        Authentication authentication,
            @PathVariable UUID reportId,
            @Valid @RequestBody AssignCaseRequest request
    ) {
                UUID currentUserId = resolveCurrentUserId(authentication);
                moderatorGuardService.requireModerator(currentUserId);
                moderationCaseService.assignCase(reportId, request.getModeratorId(), currentUserId);
        return ApiResponse.success("Case assigned successfully", null);
    }

    @PostMapping("/cases/{caseId}/resolve")
    public ApiResponse<Void> resolveCase(
                        Authentication authentication,
            @PathVariable UUID caseId,
            @Valid @RequestBody ResolveCaseRequest request
    ) {
                UUID currentUserId = resolveCurrentUserId(authentication);
                moderatorGuardService.requireModerator(currentUserId);
                moderationCaseService.resolveCase(caseId, request, currentUserId);
        return ApiResponse.success("Case resolved successfully", null);
    }

    @PostMapping("/actions")
    public ApiResponse<Map<String, UUID>> createAction(
                        Authentication authentication,
            @Valid @RequestBody CreateModerationActionRequest request
    ) {
                UUID currentUserId = resolveCurrentUserId(authentication);
                moderatorGuardService.requireModerator(currentUserId);
                UUID actionId = moderationActionService.createAction(request, currentUserId);
        return ApiResponse.success("Action created successfully", Map.of("actionId", actionId));
    }

    @PostMapping("/cases/{caseId}/appeal")
    public ApiResponse<AppealResponse> createAppeal(
            Authentication authentication,
            @PathVariable UUID caseId,
            @Valid @RequestBody CreateAppealRequest request
    ) {
        UUID currentUserId = resolveCurrentUserId(authentication);
        return ApiResponse.success("Appeal created successfully",
                appealService.createAppeal(currentUserId, caseId, request));
    }

    @GetMapping("/appeals")
    public ApiResponse<Page<AppealResponse>> getAppeals(
                        Authentication authentication,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
                UUID currentUserId = resolveCurrentUserId(authentication);
                moderatorGuardService.requireModerator(currentUserId);
        return ApiResponse.success("Fetched appeals successfully",
                appealService.getAppeals(page, size));
    }

    @PostMapping("/appeals/{appealId}/resolve")
    public ApiResponse<Void> resolveAppeal(
                        Authentication authentication,
            @PathVariable UUID appealId,
            @Valid @RequestBody ResolveAppealRequest request
    ) {
                UUID currentUserId = resolveCurrentUserId(authentication);
                moderatorGuardService.requireModerator(currentUserId);
                appealService.resolveAppeal(appealId, request, currentUserId);
        return ApiResponse.success("Appeal resolved successfully", null);
    }

        private UUID resolveCurrentUserId(Authentication authentication) {
                if (authentication == null || authentication.getPrincipal() == null) {
                        throw new ApiException(ErrorCode.UNAUTHORIZED);
                }

                Object principal = authentication.getPrincipal();
                if (principal instanceof ModerationPrincipal moderationPrincipal) {
                        return moderationPrincipal.getId();
                }
                if (principal instanceof String principalId) {
                        try {
                                return UUID.fromString(principalId);
                        } catch (IllegalArgumentException ex) {
                                throw new ApiException(ErrorCode.UNAUTHORIZED);
                        }
                }
                if (principal instanceof UserDetails userDetails) {
                        try {
                                return UUID.fromString(userDetails.getUsername());
                        } catch (IllegalArgumentException ex) {
                                throw new ApiException(ErrorCode.UNAUTHORIZED);
                        }
                }

                throw new ApiException(ErrorCode.UNAUTHORIZED);
        }
}