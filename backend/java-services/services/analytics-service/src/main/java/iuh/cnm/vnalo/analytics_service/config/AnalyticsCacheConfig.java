package iuh.cnm.vnalo.analytics_service.config;

import com.github.benmanes.caffeine.cache.Caffeine;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.cache.CacheManager;
import org.springframework.cache.caffeine.CaffeineCache;
import org.springframework.cache.caffeine.CaffeineCacheManager;
import org.springframework.cache.support.NoOpCacheManager;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
@EnableConfigurationProperties(AnalyticsCacheProperties.class)
public class AnalyticsCacheConfig {

    @Bean
    public CacheManager analyticsCacheManager(AnalyticsCacheProperties properties) {
        if (!properties.isEnabled()) {
            return new NoOpCacheManager();
        }

        CaffeineCacheManager cacheManager = new CaffeineCacheManager();
        cacheManager.registerCustomCache(
                AnalyticsCacheNames.OVERVIEW,
                Caffeine.newBuilder()
                        .maximumSize(properties.getMaximumSize())
                        .expireAfterWrite(properties.getOverviewTtl())
                        .recordStats()
                        .build()
        );
        cacheManager.registerCustomCache(
                AnalyticsCacheNames.DASHBOARD,
                Caffeine.newBuilder()
                        .maximumSize(properties.getMaximumSize())
                        .expireAfterWrite(properties.getDashboardTtl())
                        .recordStats()
                        .build()
        );
        return cacheManager;
    }
}
