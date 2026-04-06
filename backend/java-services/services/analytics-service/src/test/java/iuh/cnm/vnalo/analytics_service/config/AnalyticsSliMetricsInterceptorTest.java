package iuh.cnm.vnalo.analytics_service.config;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.Timer;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import static org.assertj.core.api.Assertions.assertThat;

class AnalyticsSliMetricsInterceptorTest {

    private SimpleMeterRegistry meterRegistry;
    private AnalyticsSliMetricsInterceptor interceptor;

    @BeforeEach
    void setUp() {
        meterRegistry = new SimpleMeterRegistry();
        interceptor = new AnalyticsSliMetricsInterceptor(meterRegistry);
    }

    @Test
    void shouldRecordSuccessMetricsForTrackedEndpoint() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/v1/analytics/dashboard");
        MockHttpServletResponse response = new MockHttpServletResponse();
        response.setStatus(200);

        interceptor.preHandle(request, response, new Object());
        interceptor.afterCompletion(request, response, new Object(), null);

        Counter requests = meterRegistry.find("analytics.sli.requests.total")
                .tag("endpoint", "dashboard")
                .counter();
        Counter errors = meterRegistry.find("analytics.sli.errors.total")
                .tag("endpoint", "dashboard")
                .counter();
        Timer latency = meterRegistry.find("analytics.sli.latency")
                .tag("endpoint", "dashboard")
                .tag("outcome", "success")
                .timer();

        assertThat(requests).isNotNull();
        assertThat(requests.count()).isEqualTo(1.0);
        assertThat(errors).isNull();
        assertThat(latency).isNotNull();
        assertThat(latency.count()).isEqualTo(1L);
    }

    @Test
    void shouldRecordErrorMetricsWhenExceptionOccurs() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/api/v1/analytics/backfill");
        MockHttpServletResponse response = new MockHttpServletResponse();
        response.setStatus(500);

        interceptor.preHandle(request, response, new Object());
        interceptor.afterCompletion(request, response, new Object(), new RuntimeException("boom"));

        Counter errors = meterRegistry.find("analytics.sli.errors.total")
                .tag("endpoint", "backfill")
                .counter();
        Timer latency = meterRegistry.find("analytics.sli.latency")
                .tag("endpoint", "backfill")
                .tag("outcome", "error")
                .timer();

        assertThat(errors).isNotNull();
        assertThat(errors.count()).isEqualTo(1.0);
        assertThat(latency).isNotNull();
        assertThat(latency.count()).isEqualTo(1L);
    }

    @Test
    void shouldSkipUntrackedEndpoint() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/v1/analytics/users/trend");
        MockHttpServletResponse response = new MockHttpServletResponse();
        response.setStatus(200);

        interceptor.preHandle(request, response, new Object());
        interceptor.afterCompletion(request, response, new Object(), null);

        assertThat(meterRegistry.find("analytics.sli.requests.total").counters()).isEmpty();
        assertThat(meterRegistry.find("analytics.sli.latency").timers()).isEmpty();
    }
}