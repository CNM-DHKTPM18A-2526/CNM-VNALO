package iuh.cnm.vnalo.analytics_service;

import iuh.cnm.vnalo.analytics_service.service.AnalyticsOverviewService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest
@ActiveProfiles("test")
class AnalyticsServiceApplicationTests {

    @Autowired
    private AnalyticsOverviewService overviewService;

    @Test
    void contextLoads() {
        assertThat(overviewService).isNotNull();
    }
}