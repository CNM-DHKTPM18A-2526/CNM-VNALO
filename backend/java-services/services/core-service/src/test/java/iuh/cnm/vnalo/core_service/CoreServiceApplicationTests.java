package iuh.cnm.vnalo.core_service;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.test.context.TestPropertySource;

@SpringBootTest
@TestPropertySource(properties = {
    "spring.datasource.url=jdbc:h2:mem:testdb;DB_CLOSE_DELAY=-1;MODE=PostgreSQL",
    "spring.datasource.driver-class-name=org.h2.Driver",
    "spring.jpa.hibernate.ddl-auto=create-drop",
    "spring.flyway.enabled=false",
    "spring.autoconfigure.exclude=org.springframework.boot.autoconfigure.data.redis.RedisAutoConfiguration,org.springframework.boot.autoconfigure.kafka.KafkaAutoConfiguration",
    "jwt.secret=ZGV2ZWxvcG1lbnQtdGVzdC1qd3Qtc2VjcmV0LWZvci1jb3JlLXNlcnZpY2UtY29udGV4dC1sb2Fkcy1vbmx5",
    "jwt.issuer=test-suite",
    "ai.internal-secret=test-ai-internal-secret"
})
class CoreServiceApplicationTests {

    @MockBean
    private KafkaTemplate<String, Object> kafkaTemplate;

    @Test
    void contextLoads() {
        // Verify Spring context starts successfully
    }
}
