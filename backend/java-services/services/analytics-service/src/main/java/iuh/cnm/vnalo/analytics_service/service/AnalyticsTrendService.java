package iuh.cnm.vnalo.analytics_service.service;

import iuh.cnm.vnalo.analytics_service.model.dto.response.DailyTrendPointResponse;
import iuh.cnm.vnalo.analytics_service.query.SharedConversationAnalyticsQueryService;
import iuh.cnm.vnalo.analytics_service.query.SharedMessageAnalyticsQueryService;
import iuh.cnm.vnalo.analytics_service.query.SharedModerationAnalyticsQueryService;
import iuh.cnm.vnalo.analytics_service.query.SharedUserAnalyticsQueryService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.List;

@Service
@RequiredArgsConstructor
public class AnalyticsTrendService {
    private final SharedUserAnalyticsQueryService userQueryService;
    private final SharedConversationAnalyticsQueryService conversationQueryService;
    private final SharedMessageAnalyticsQueryService messageQueryService;
    private final SharedModerationAnalyticsQueryService moderationQueryService;

    public List<DailyTrendPointResponse> getUserTrend(LocalDate from, LocalDate to) {
        return userQueryService.getUserRegistrationTrend(from, to);
    }

    public List<DailyTrendPointResponse> getConversationTrend(LocalDate from, LocalDate to) {
        return conversationQueryService.getConversationTrend(from, to);
    }

    public List<DailyTrendPointResponse> getMessageTrend(LocalDate from, LocalDate to) {
        return messageQueryService.getMessageTrend(from, to);
    }

    public List<DailyTrendPointResponse> getMediaTrend(LocalDate from, LocalDate to) {
        return messageQueryService.getMediaTrend(from, to);
    }

    public List<DailyTrendPointResponse> getGroupCreationTrend(LocalDate from, LocalDate to) {
        return conversationQueryService.getGroupCreationTrend(from, to);
    }

    public List<DailyTrendPointResponse> getReportTrend(LocalDate from, LocalDate to) {
        return moderationQueryService.getReportTrend(from, to);
    }

    public List<DailyTrendPointResponse> getModerationActionTrend(LocalDate from, LocalDate to) {
        return moderationQueryService.getModerationActionTrend(from, to);
    }
}