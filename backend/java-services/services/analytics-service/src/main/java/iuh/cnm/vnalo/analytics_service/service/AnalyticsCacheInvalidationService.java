package iuh.cnm.vnalo.analytics_service.service;

import iuh.cnm.vnalo.analytics_service.config.AnalyticsCacheNames;
import io.micrometer.core.instrument.MeterRegistry;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.cache.Cache;
import org.springframework.cache.CacheManager;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
@Slf4j
public class AnalyticsCacheInvalidationService {
    private final CacheManager cacheManager;
    private final MeterRegistry meterRegistry;

    public void invalidateReadCaches(String reason) {
        clearCache(AnalyticsCacheNames.OVERVIEW);
        clearCache(AnalyticsCacheNames.DASHBOARD);
        meterRegistry.counter("analytics.cache.invalidations", "reason", reason).increment();
        log.info("analytics_cache_invalidated reason={} caches={},{}",
                reason, AnalyticsCacheNames.OVERVIEW, AnalyticsCacheNames.DASHBOARD);
    }

    private void clearCache(String cacheName) {
        Cache cache = cacheManager.getCache(cacheName);
        if (cache != null) {
            cache.clear();
        }
    }
}
