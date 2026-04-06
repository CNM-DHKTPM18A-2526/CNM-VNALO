package iuh.cnm.vnalo.analytics_service.service;

import iuh.cnm.vnalo.analytics_service.model.dto.response.MessageTypeCountResponse;
import iuh.cnm.vnalo.analytics_service.model.dto.response.ReasonCountResponse;
import iuh.cnm.vnalo.analytics_service.query.SharedConversationAnalyticsQueryService;
import iuh.cnm.vnalo.analytics_service.query.SharedMessageAnalyticsQueryService;
import iuh.cnm.vnalo.analytics_service.query.SharedModerationAnalyticsQueryService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.List;

@Service
@RequiredArgsConstructor
public class AnalyticsBreakdownService {
    private final SharedModerationAnalyticsQueryService moderationQueryService;
    private final SharedMessageAnalyticsQueryService messageQueryService;
    private final SharedConversationAnalyticsQueryService conversationQueryService;

    public List<ReasonCountResponse> getReportReasons(LocalDate from, LocalDate to) {
        return moderationQueryService.getReportReasonBreakdown(from, to);
    }

    public List<ReasonCountResponse> getReportTargetTypes(LocalDate from, LocalDate to) {
        return moderationQueryService.getReportTargetTypeBreakdown(from, to);
    }

    public List<MessageTypeCountResponse> getMessageTypes(LocalDate from, LocalDate to) {
        return messageQueryService.getMessageTypeBreakdown(from, to);
    }

    public List<ReasonCountResponse> getConversationTypes(LocalDate from, LocalDate to) {
        return conversationQueryService.getConversationTypeBreakdown(from, to);
    }
}