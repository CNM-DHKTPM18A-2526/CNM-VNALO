package iuh.cnm.vnalo.mediaservice.config;

import iuh.cnm.vnalo.mediaservice.exception.RateLimitExceededException;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Simple in-memory rate limiter per IP address.
 * Allows max 300 requests per minute per IP.
 * For production, use Redis-based rate limiting (e.g. Bucket4j + Redis).
 */
@Component
public class RateLimitFilter extends OncePerRequestFilter {

    private static final int MAX_REQUESTS_PER_MINUTE = 300;
    private static final long WINDOW_MS = 60_000; // 1 minute

    private final Map<String, RateLimitBucket> buckets = new ConcurrentHashMap<>();

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {

        String clientIp = getClientIp(request);
        RateLimitBucket bucket = buckets.computeIfAbsent(clientIp, k -> new RateLimitBucket());

        if (!bucket.tryConsume()) {
            response.setStatus(HttpServletResponse.SC_TOO_MANY_REQUESTS);
            response.setHeader("Retry-After", "60");
            response.setContentType("application/json");
            response.getWriter().write(
                    "{\"success\":false,\"status\":429,\"message\":\"Too many requests. Please try again later.\"}"
            );
            return;
        }

        filterChain.doFilter(request, response);
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String path = request.getRequestURI();
        // Don't rate limit health checks and Swagger
        return path.startsWith("/actuator") || path.startsWith("/swagger") || path.startsWith("/v3/api-docs");
    }

    private String getClientIp(HttpServletRequest request) {
        String xForwardedFor = request.getHeader("X-Forwarded-For");
        if (xForwardedFor != null && !xForwardedFor.isEmpty()) {
            return xForwardedFor.split(",")[0].trim();
        }
        return request.getRemoteAddr();
    }

    /**
     * Simple sliding window rate limit bucket.
     */
    private static class RateLimitBucket {
        private final AtomicInteger count = new AtomicInteger(0);
        private volatile long windowStart = System.currentTimeMillis();

        boolean tryConsume() {
            long now = System.currentTimeMillis();
            if (now - windowStart > WINDOW_MS) {
                // Reset window
                synchronized (this) {
                    if (now - windowStart > WINDOW_MS) {
                        count.set(0);
                        windowStart = now;
                    }
                }
            }
            return count.incrementAndGet() <= MAX_REQUESTS_PER_MINUTE;
        }
    }
}
