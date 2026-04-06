package iuh.cnm.vnalo.analytics_service.config;

import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.lang.NonNull;
import org.springframework.lang.Nullable;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

import java.util.concurrent.TimeUnit;

@Component
@RequiredArgsConstructor
public class AnalyticsSliMetricsInterceptor implements HandlerInterceptor {
    private static final String ATTR_START_NANOS = "analytics.sli.startNanos";
    private static final String ATTR_ENDPOINT_TAG = "analytics.sli.endpointTag";

    private final MeterRegistry meterRegistry;

    @Override
    public boolean preHandle(
            @NonNull HttpServletRequest request,
            @NonNull HttpServletResponse response,
            @NonNull Object handler
    ) {
        String endpointTag = resolveEndpointTag(request.getMethod(), request.getRequestURI());
        if (endpointTag == null) {
            return true;
        }

        request.setAttribute(ATTR_START_NANOS, System.nanoTime());
        request.setAttribute(ATTR_ENDPOINT_TAG, endpointTag);

        meterRegistry.counter("analytics.sli.requests.total", "endpoint", endpointTag).increment();
        return true;
    }

    @Override
    public void afterCompletion(
            @NonNull HttpServletRequest request,
            @NonNull HttpServletResponse response,
            @NonNull Object handler,
            @Nullable Exception ex
    ) {
        Object startObj = request.getAttribute(ATTR_START_NANOS);
        Object endpointObj = request.getAttribute(ATTR_ENDPOINT_TAG);

        if (!(startObj instanceof Long startNanos) || !(endpointObj instanceof String endpointTag)) {
            return;
        }

        long elapsedNanos = System.nanoTime() - startNanos;
        boolean isError = ex != null || response.getStatus() >= 500;
        String outcome = isError ? "error" : "success";

        Timer.builder("analytics.sli.latency")
                .tag("endpoint", endpointTag)
                .tag("outcome", outcome)
                .register(meterRegistry)
                .record(elapsedNanos, TimeUnit.NANOSECONDS);

        if (isError) {
            meterRegistry.counter("analytics.sli.errors.total", "endpoint", endpointTag).increment();
        }
    }

    private String resolveEndpointTag(String method, String uri) {
        if ("GET".equals(method) && "/api/v1/analytics/overview".equals(uri)) {
            return "overview";
        }
        if ("GET".equals(method) && "/api/v1/analytics/dashboard".equals(uri)) {
            return "dashboard";
        }
        if ("POST".equals(method) && "/api/v1/analytics/backfill".equals(uri)) {
            return "backfill";
        }
        return null;
    }
}