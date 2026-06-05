package iuh.cnm.vnalo.analytics_service.controller;

import iuh.cnm.vnalo.analytics_service.model.dto.ApiResponse;
import iuh.cnm.vnalo.analytics_service.model.dto.request.ClientAnalyticsEventRequest;
import iuh.cnm.vnalo.analytics_service.model.dto.response.*;
import iuh.cnm.vnalo.analytics_service.security.AnalyticsAccessGuardService;
import iuh.cnm.vnalo.analytics_service.security.AnalyticsPrincipal;
import iuh.cnm.vnalo.analytics_service.service.AnalyticsBreakdownService;
import iuh.cnm.vnalo.analytics_service.service.AnalyticsDashboardService;
import iuh.cnm.vnalo.analytics_service.service.AnalyticsOverviewService;
import iuh.cnm.vnalo.analytics_service.service.AnalyticsTrendService;
import iuh.cnm.vnalo.analytics_service.service.BehavioralAnalyticsService;
import iuh.cnm.vnalo.analytics_service.model.dto.response.BackfillJobResponse;
import iuh.cnm.vnalo.analytics_service.service.BackfillJobService;
import iuh.cnm.vnalo.analytics_service.validator.DateRangeValidator;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import jakarta.validation.Valid;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/analytics")
@RequiredArgsConstructor
public class AnalyticsController {
    private final AnalyticsAccessGuardService accessGuardService;
    private final DateRangeValidator dateRangeValidator;
    private final AnalyticsOverviewService overviewService;
    private final AnalyticsTrendService trendService;
    private final AnalyticsBreakdownService breakdownService;
    private final AnalyticsDashboardService dashboardService;
    private final BackfillJobService backfillJobService;
    private final BehavioralAnalyticsService behavioralAnalyticsService;

    @PostMapping("/events")
    public ApiResponse<Map<String, UUID>> ingestClientEvent(
            @AuthenticationPrincipal AnalyticsPrincipal principal,
            @Valid @RequestBody ClientAnalyticsEventRequest request
    ) {
        UUID eventId = behavioralAnalyticsService.ingestClientEvent(principal.getUserId(), request);
        return ApiResponse.success("Client analytics event recorded", Map.of("eventId", eventId));
    }

    @GetMapping("/behavior/summary")
    public ApiResponse<BehavioralAnalyticsSummaryResponse> getBehavioralSummary(
            @AuthenticationPrincipal AnalyticsPrincipal principal,
            @RequestParam LocalDate from,
            @RequestParam LocalDate to
    ) {
        accessGuardService.requireAnalyticsAccess(principal.getUserId());
        dateRangeValidator.validate(from, to);
        return ApiResponse.success("Behavioral analytics summary fetched successfully",
                behavioralAnalyticsService.getSummary(from, to));
    }

    @GetMapping("/overview")
    public ApiResponse<AnalyticsOverviewResponse> getOverview(
            @AuthenticationPrincipal AnalyticsPrincipal principal,
            @RequestParam LocalDate from,
            @RequestParam LocalDate to
    ) {
        accessGuardService.requireAnalyticsAccess(principal.getUserId());
        dateRangeValidator.validate(from, to);
        return ApiResponse.success("Overview fetched successfully",
                overviewService.getOverview(from, to));
    }

    @GetMapping("/users/trend")
    public ApiResponse<List<DailyTrendPointResponse>> getUserTrend(
            @AuthenticationPrincipal AnalyticsPrincipal principal,
            @RequestParam LocalDate from,
            @RequestParam LocalDate to
    ) {
        accessGuardService.requireAnalyticsAccess(principal.getUserId());
        dateRangeValidator.validate(from, to);
        return ApiResponse.success("User trend fetched successfully",
                trendService.getUserTrend(from, to));
    }

    @GetMapping("/conversations/trend")
    public ApiResponse<List<DailyTrendPointResponse>> getConversationTrend(
            @AuthenticationPrincipal AnalyticsPrincipal principal,
            @RequestParam LocalDate from,
            @RequestParam LocalDate to
    ) {
        accessGuardService.requireAnalyticsAccess(principal.getUserId());
        dateRangeValidator.validate(from, to);
        return ApiResponse.success("Conversation trend fetched successfully",
                trendService.getConversationTrend(from, to));
    }

    @GetMapping("/messages/trend")
    public ApiResponse<List<DailyTrendPointResponse>> getMessageTrend(
            @AuthenticationPrincipal AnalyticsPrincipal principal,
            @RequestParam LocalDate from,
            @RequestParam LocalDate to
    ) {
        accessGuardService.requireAnalyticsAccess(principal.getUserId());
        dateRangeValidator.validate(from, to);
        return ApiResponse.success("Message trend fetched successfully",
                trendService.getMessageTrend(from, to));
    }

    @GetMapping("/media/trend")
    public ApiResponse<List<DailyTrendPointResponse>> getMediaTrend(
            @AuthenticationPrincipal AnalyticsPrincipal principal,
            @RequestParam LocalDate from,
            @RequestParam LocalDate to
    ) {
        accessGuardService.requireAnalyticsAccess(principal.getUserId());
        dateRangeValidator.validate(from, to);
        return ApiResponse.success("Media trend fetched successfully",
                trendService.getMediaTrend(from, to));
    }

    @GetMapping("/groups/trend")
    public ApiResponse<List<DailyTrendPointResponse>> getGroupTrend(
            @AuthenticationPrincipal AnalyticsPrincipal principal,
            @RequestParam LocalDate from,
            @RequestParam LocalDate to
    ) {
        accessGuardService.requireAnalyticsAccess(principal.getUserId());
        dateRangeValidator.validate(from, to);
        return ApiResponse.success("Group creation trend fetched successfully",
                trendService.getGroupCreationTrend(from, to));
    }

    @GetMapping("/users/active-summary")
    public ApiResponse<ActiveUserSummaryResponse> getActiveUserSummary(
            @AuthenticationPrincipal AnalyticsPrincipal principal,
            @RequestParam LocalDate from,
            @RequestParam LocalDate to
    ) {
        accessGuardService.requireAnalyticsAccess(principal.getUserId());
        dateRangeValidator.validate(from, to);
        return ApiResponse.success("Active user summary fetched successfully",
                dashboardService.getActiveUserSummary(from, to));
    }

    @GetMapping("/users/top-active")
    public ApiResponse<List<TopActiveUserResponse>> getTopActiveUsers(
            @AuthenticationPrincipal AnalyticsPrincipal principal,
            @RequestParam LocalDate from,
            @RequestParam LocalDate to,
            @RequestParam(defaultValue = "10") int limit
    ) {
        accessGuardService.requireAnalyticsAccess(principal.getUserId());
        dateRangeValidator.validate(from, to);
        int normalizedLimit = Math.min(Math.max(limit, 1), 50);
        return ApiResponse.success("Top active users fetched successfully",
                dashboardService.getTopActiveUsers(from, to, normalizedLimit));
    }

    @GetMapping("/dashboard")
    public ApiResponse<AnalyticsDashboardResponse> getDashboard(
            @AuthenticationPrincipal AnalyticsPrincipal principal,
            @RequestParam LocalDate from,
            @RequestParam LocalDate to,
            @RequestParam(defaultValue = "10") int topLimit
    ) {
        accessGuardService.requireAnalyticsAccess(principal.getUserId());
        dateRangeValidator.validate(from, to);
        int normalizedTopLimit = Math.min(Math.max(topLimit, 1), 50);
        return ApiResponse.success("Dashboard data fetched successfully",
                dashboardService.getDashboard(from, to, normalizedTopLimit));
    }

    @GetMapping("/reports/trend")
    public ApiResponse<List<DailyTrendPointResponse>> getReportTrend(
            @AuthenticationPrincipal AnalyticsPrincipal principal,
            @RequestParam LocalDate from,
            @RequestParam LocalDate to
    ) {
        accessGuardService.requireAnalyticsAccess(principal.getUserId());
        dateRangeValidator.validate(from, to);
        return ApiResponse.success("Report trend fetched successfully",
                trendService.getReportTrend(from, to));
    }

    @GetMapping("/actions/trend")
    public ApiResponse<List<DailyTrendPointResponse>> getActionTrend(
            @AuthenticationPrincipal AnalyticsPrincipal principal,
            @RequestParam LocalDate from,
            @RequestParam LocalDate to
    ) {
        accessGuardService.requireAnalyticsAccess(principal.getUserId());
        dateRangeValidator.validate(from, to);
        return ApiResponse.success("Moderation action trend fetched successfully",
                trendService.getModerationActionTrend(from, to));
    }

    @GetMapping("/reports/reasons")
    public ApiResponse<List<ReasonCountResponse>> getReportReasons(
            @AuthenticationPrincipal AnalyticsPrincipal principal,
            @RequestParam LocalDate from,
            @RequestParam LocalDate to
    ) {
        accessGuardService.requireAnalyticsAccess(principal.getUserId());
        dateRangeValidator.validate(from, to);
        return ApiResponse.success("Report reasons fetched successfully",
                breakdownService.getReportReasons(from, to));
    }

    @GetMapping("/reports/target-types")
    public ApiResponse<List<ReasonCountResponse>> getReportTargetTypes(
            @AuthenticationPrincipal AnalyticsPrincipal principal,
            @RequestParam LocalDate from,
            @RequestParam LocalDate to
    ) {
        accessGuardService.requireAnalyticsAccess(principal.getUserId());
        dateRangeValidator.validate(from, to);
        return ApiResponse.success("Report target types fetched successfully",
                breakdownService.getReportTargetTypes(from, to));
    }

    @GetMapping("/messages/types")
    public ApiResponse<List<MessageTypeCountResponse>> getMessageTypes(
            @AuthenticationPrincipal AnalyticsPrincipal principal,
            @RequestParam LocalDate from,
            @RequestParam LocalDate to
    ) {
        accessGuardService.requireAnalyticsAccess(principal.getUserId());
        dateRangeValidator.validate(from, to);
        return ApiResponse.success("Message types fetched successfully",
                breakdownService.getMessageTypes(from, to));
    }

    @GetMapping("/conversations/types")
    public ApiResponse<List<ReasonCountResponse>> getConversationTypes(
            @AuthenticationPrincipal AnalyticsPrincipal principal,
            @RequestParam LocalDate from,
            @RequestParam LocalDate to
    ) {
        accessGuardService.requireAnalyticsAccess(principal.getUserId());
        dateRangeValidator.validate(from, to);
        return ApiResponse.success("Conversation types fetched successfully",
                breakdownService.getConversationTypes(from, to));
    }

    @PostMapping("/backfill")
    public ApiResponse<BackfillJobResponse> backfillMetrics(
            @AuthenticationPrincipal AnalyticsPrincipal principal,
            @RequestParam LocalDate from,
            @RequestParam LocalDate to
    ) {
        accessGuardService.requireAnalyticsAdmin(principal.getUserId());
        dateRangeValidator.validate(from, to);

        BackfillJobResponse job = backfillJobService.runBackfill(from, to);
        return ApiResponse.success("Backfill completed successfully", job);
    }
}
