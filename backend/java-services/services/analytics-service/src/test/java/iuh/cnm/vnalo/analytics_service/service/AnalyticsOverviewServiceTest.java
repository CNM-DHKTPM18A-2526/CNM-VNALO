package iuh.cnm.vnalo.analytics_service.service;

import iuh.cnm.vnalo.analytics_service.model.dto.response.AnalyticsOverviewResponse;
import iuh.cnm.vnalo.analytics_service.query.SharedConversationAnalyticsQueryService;
import iuh.cnm.vnalo.analytics_service.query.SharedMessageAnalyticsQueryService;
import iuh.cnm.vnalo.analytics_service.query.SharedModerationAnalyticsQueryService;
import iuh.cnm.vnalo.analytics_service.query.SharedUserAnalyticsQueryService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AnalyticsOverviewServiceTest {

    @Mock
    private SharedUserAnalyticsQueryService userQueryService;

    @Mock
    private SharedConversationAnalyticsQueryService conversationQueryService;

    @Mock
    private SharedMessageAnalyticsQueryService messageQueryService;

    @Mock
    private SharedModerationAnalyticsQueryService moderationQueryService;

    @InjectMocks
    private AnalyticsOverviewService overviewService;

    @Test
    void getOverview_shouldReturnOverviewResponse() {
        // Given
        LocalDate from = LocalDate.of(2026, 3, 1);
        LocalDate to = LocalDate.of(2026, 3, 18);

        when(userQueryService.countRegisteredUsers(from, to)).thenReturn(1000L);
        when(conversationQueryService.countCreatedConversations(from, to)).thenReturn(500L);
        when(messageQueryService.countMessagesSent(from, to)).thenReturn(10000L);
        when(moderationQueryService.countReports(from, to)).thenReturn(50L);
        when(moderationQueryService.countModerationActions(from, to)).thenReturn(25L);

        // When
        AnalyticsOverviewResponse response = overviewService.getOverview(from, to);

        // Then
        assertThat(response).isNotNull();
        assertThat(response.getUsersRegistered()).isEqualTo(1000L);
        assertThat(response.getConversationsCreated()).isEqualTo(500L);
        assertThat(response.getMessagesSent()).isEqualTo(10000L);
        assertThat(response.getReportsCreated()).isEqualTo(50L);
        assertThat(response.getModerationActionsTaken()).isEqualTo(25L);
    }
}