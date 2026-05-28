package iuh.cnm.vnalo.core_service.service.face;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * In-memory rate-limiting service for face-auth endpoints.
 *
 * <p>Two mechanisms:
 * <ol>
 *   <li>IP-based sliding window — protects {@code /face/liveness-check} and {@code /auth/lookup}
 *       from enumeration / oracle attacks.</li>
 *   <li>UserId-based failure counter — locks {@code /face/verify} temporarily after repeated
 *       failures to prevent brute-force face spoofing attacks.</li>
 * </ol>
 *
 * <p>NOTE: This is an in-process, non-persistent store. Limits reset on pod restart.
 * For production at scale, replace with Redis + Lua scripts.
 */
@Service
@Slf4j
public class RateLimitService {

    // -------------------------------------------------------------------------
    // IP-based sliding-window rate limiting
    // -------------------------------------------------------------------------

    /** Max requests per window per IP for public face/lookup endpoints. */
    private static final int IP_MAX_REQUESTS = 10;

    /** Sliding window duration in milliseconds (1 minute). */
    private static final long IP_WINDOW_MS = 60_000L;

    /** Evict stale IP entries after this many milliseconds of inactivity (5 minutes). */
    private static final long IP_EVICT_AFTER_MS = 300_000L;

    private final Map<String, IpEntry> ipWindows = new ConcurrentHashMap<>();

    /**
     * Returns {@code true} if the given IP has exceeded the rate limit.
     * Call this before processing the request; if it returns true, reject immediately.
     */
    public boolean isIpRateLimited(String ip) {
        if (ip == null || ip.isBlank()) return false;

        long now = Instant.now().toEpochMilli();
        IpEntry entry = ipWindows.computeIfAbsent(ip, k -> new IpEntry());

        synchronized (entry) {
            Deque<Long> window = entry.timestamps;

            // Evict timestamps outside the sliding window
            while (!window.isEmpty() && window.peekFirst() < now - IP_WINDOW_MS) {
                window.pollFirst();
            }

            if (window.size() >= IP_MAX_REQUESTS) {
                log.warn("[RateLimit] IP={} exceeded {} req/min limit", ip, IP_MAX_REQUESTS);
                return true;
            }

            window.addLast(now);
            entry.lastSeen = now;
            return false;
        }
    }

    /** Periodically called to evict stale IP entries (avoid unbounded growth). */
    public void evictStaleIpEntries() {
        long cutoff = Instant.now().toEpochMilli() - IP_EVICT_AFTER_MS;
        ipWindows.entrySet().removeIf(e -> e.getValue().lastSeen < cutoff);
    }

    // -------------------------------------------------------------------------
    // UserId-based brute-force protection for /face/verify
    // -------------------------------------------------------------------------

    /** Max consecutive verification failures before locking. */
    private static final int MAX_VERIFY_FAILURES = 5;

    /** Lock duration in milliseconds (15 minutes). */
    private static final long VERIFY_LOCK_DURATION_MS = 15 * 60_000L;

    private final Map<UUID, FailureRecord> verifyFailures = new ConcurrentHashMap<>();

    /**
     * Returns {@code true} if the userId is currently locked out from face verification.
     */
    public boolean isVerifyLocked(UUID userId) {
        FailureRecord record = verifyFailures.get(userId);
        if (record == null) return false;

        long now = Instant.now().toEpochMilli();
        if (record.lockedUntil > 0 && now < record.lockedUntil) {
            long remainingSecs = (record.lockedUntil - now) / 1000;
            log.warn("[BruteForce] userId={} is locked for {}s more", userId, remainingSecs);
            return true;
        }

        // Lock expired — reset
        if (record.lockedUntil > 0 && now >= record.lockedUntil) {
            verifyFailures.remove(userId);
        }
        return false;
    }

    /**
     * Records a failed verification attempt for the given userId.
     * After {@link #MAX_VERIFY_FAILURES} consecutive failures, the account is locked
     * for {@link #VERIFY_LOCK_DURATION_MS}.
     */
    public void recordVerifyFailure(UUID userId) {
        long now = Instant.now().toEpochMilli();
        FailureRecord record = verifyFailures.computeIfAbsent(userId, k -> new FailureRecord());

        synchronized (record) {
            record.failureCount++;
            record.lastFailureAt = now;

            if (record.failureCount >= MAX_VERIFY_FAILURES) {
                record.lockedUntil = now + VERIFY_LOCK_DURATION_MS;
                log.warn("[BruteForce] userId={} locked after {} failures. Locked until={}",
                        userId, record.failureCount, Instant.ofEpochMilli(record.lockedUntil));
            } else {
                log.info("[BruteForce] userId={} failure count={}/{}", userId, record.failureCount, MAX_VERIFY_FAILURES);
            }
        }
    }

    /**
     * Resets the failure counter for the given userId after a successful verification.
     */
    public void resetVerifyFailures(UUID userId) {
        if (verifyFailures.remove(userId) != null) {
            log.info("[BruteForce] userId={} failure counter reset after success", userId);
        }
    }

    // -------------------------------------------------------------------------
    // Internal data holders
    // -------------------------------------------------------------------------

    private static class IpEntry {
        final Deque<Long> timestamps = new ArrayDeque<>();
        volatile long lastSeen = Instant.now().toEpochMilli();
    }

    private static class FailureRecord {
        volatile int failureCount = 0;
        volatile long lastFailureAt = 0L;
        volatile long lockedUntil = 0L;
    }
}
