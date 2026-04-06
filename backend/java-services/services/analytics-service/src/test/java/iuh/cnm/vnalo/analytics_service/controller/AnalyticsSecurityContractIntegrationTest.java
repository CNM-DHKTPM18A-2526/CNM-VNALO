package iuh.cnm.vnalo.analytics_service.controller;

import iuh.cnm.vnalo.analytics_service.exception.ApiException;
import iuh.cnm.vnalo.analytics_service.exception.ErrorCode;
import iuh.cnm.vnalo.analytics_service.security.AnalyticsAccessGuardService;
import iuh.cnm.vnalo.analytics_service.security.AnalyticsPrincipal;
import iuh.cnm.vnalo.analytics_service.service.AnalyticsEventIngestionService;
import iuh.cnm.vnalo.analytics_service.service.BackfillJobService;
import iuh.cnm.vnalo.analytics_service.service.DailyMetricAggregationService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doNothing;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AnalyticsSecurityContractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private AnalyticsAccessGuardService accessGuardService;

    @MockBean
    private DailyMetricAggregationService aggregationService;

    @MockBean
    private AnalyticsEventIngestionService ingestionService;

    @MockBean
    private BackfillJobService backfillJobService;

    @Test
    void analyticsEndpoint_shouldReturn401_whenUnauthenticated() throws Exception {
        mockMvc.perform(get("/api/v1/analytics/overview")
                        .param("from", "2026-03-01")
                        .param("to", "2026-03-18"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.errorCode").value("ERR_401"));
    }

    @Test
    void analyticsEndpoint_shouldReturn403_whenGuardRejectsUser() throws Exception {
        doThrow(new ApiException(ErrorCode.ANALYTICS_FORBIDDEN))
                .when(accessGuardService).requireAnalyticsAccess(any(UUID.class));

        mockMvc.perform(get("/api/v1/analytics/overview")
                        .with(authentication(buildAuthentication()))
                        .param("from", "2026-03-01")
                        .param("to", "2026-03-18"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.errorCode").value("ANA_001"));
    }

    @Test
    void analyticsEndpoint_shouldReturn400_whenDateFormatInvalid() throws Exception {
        doNothing().when(accessGuardService).requireAnalyticsAccess(any(UUID.class));

        mockMvc.perform(get("/api/v1/analytics/overview")
                        .with(authentication(buildAuthentication()))
                        .param("from", "invalid-date")
                        .param("to", "2026-03-18"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.errorCode").value("ANA_002"));
    }

    @Test
    void analyticsEndpoint_shouldReturn400_whenFromAfterTo() throws Exception {
        doNothing().when(accessGuardService).requireAnalyticsAccess(any(UUID.class));

        mockMvc.perform(get("/api/v1/analytics/overview")
                        .with(authentication(buildAuthentication()))
                        .param("from", "2026-03-19")
                        .param("to", "2026-03-18"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.errorCode").value("ANA_002"));
    }

            @Test
            void backfill_shouldReturn403_whenGuardRejectsNonAdmin() throws Exception {
            doThrow(new ApiException(ErrorCode.ANALYTICS_FORBIDDEN))
                .when(accessGuardService).requireAnalyticsAdmin(any(UUID.class));

            mockMvc.perform(post("/api/v1/analytics/backfill")
                    .with(authentication(buildAuthentication()))
                    .param("from", "2026-03-16")
                    .param("to", "2026-03-18"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.errorCode").value("ANA_001"));
            }

            @Test
            void backfill_shouldAggregateEachDay_whenAdminAllowed() throws Exception {
            doNothing().when(accessGuardService).requireAnalyticsAdmin(any(UUID.class));
            when(backfillJobService.runBackfill(eq(java.time.LocalDate.of(2026, 3, 16)), eq(java.time.LocalDate.of(2026, 3, 18))))
                    .thenReturn(iuh.cnm.vnalo.analytics_service.model.dto.response.BackfillJobResponse.builder()
                            .jobId(UUID.fromString("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"))
                            .status(iuh.cnm.vnalo.analytics_service.model.enums.BackfillJobStatus.COMPLETED)
                            .fromDate(java.time.LocalDate.of(2026, 3, 16))
                            .toDate(java.time.LocalDate.of(2026, 3, 18))
                            .totalDays(3)
                            .processedDays(3)
                            .build());

            mockMvc.perform(post("/api/v1/analytics/backfill")
                    .with(authentication(buildAuthentication()))
                    .param("from", "2026-03-16")
                    .param("to", "2026-03-18"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.jobId").value("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"))
                .andExpect(jsonPath("$.data.status").value("COMPLETED"))
                .andExpect(jsonPath("$.data.totalDays").value(3))
                .andExpect(jsonPath("$.data.processedDays").value(3));

            verify(backfillJobService).runBackfill(eq(java.time.LocalDate.of(2026, 3, 16)), eq(java.time.LocalDate.of(2026, 3, 18)));
            }

            @Test
            void internalEventEndpoint_shouldReturn401_whenInternalApiKeyMissing() throws Exception {
            mockMvc.perform(post("/internal/events")
                    .contentType("application/json")
                    .content("""
                        {
                          "eventType": "MESSAGE_SENT",
                          "sourceService": "core-service",
                          "occurredAt": "2026-03-18T10:00:00Z"
                        }
                        """))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.errorCode").value("ERR_401"));
            }

            @Test
            void internalEventEndpoint_shouldReturn200_whenInternalApiKeyIsValid() throws Exception {
            UUID eventId = UUID.fromString("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");
            when(ingestionService.ingestEvent(any())).thenReturn(eventId);

            mockMvc.perform(post("/internal/events")
                    .header("X-Internal-Api-Key", "test-analytics-internal-key")
                    .contentType("application/json")
                    .content("""
                        {
                          "eventType": "MESSAGE_SENT",
                          "sourceService": "core-service",
                          "occurredAt": "2026-03-18T10:00:00Z",
                          "payloadJson": "{}"
                        }
                        """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.eventId").value(eventId.toString()));
            }

        @Test
        void internalEventEndpoint_shouldReturn403_whenAuthenticatedUserLacksInternalAuthority() throws Exception {
                mockMvc.perform(post("/internal/events")
                                                .with(authentication(buildAuthentication()))
                                                .contentType("application/json")
                                                .content("""
                                                                {
                                                                    "eventType": "MESSAGE_SENT",
                                                                    "sourceService": "core-service",
                                                                    "occurredAt": "2026-03-18T10:00:00Z"
                                                                }
                                                                """))
                                .andExpect(status().isForbidden())
                                .andExpect(jsonPath("$.success").value(false))
                                .andExpect(jsonPath("$.errorCode").value("ERR_403"));

                verifyNoInteractions(ingestionService);
        }

    private UsernamePasswordAuthenticationToken buildAuthentication() {
        AnalyticsPrincipal principal = AnalyticsPrincipal.builder()
                .userId(UUID.fromString("11111111-1111-1111-1111-111111111111"))
                .username("analytics-tester")
                .authorities(List.of())
                .build();
        return new UsernamePasswordAuthenticationToken(principal, null, principal.getAuthorities());
    }
}
