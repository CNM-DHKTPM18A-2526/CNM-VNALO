package iuh.cnm.vnalo.moderation_service.regression;

import iuh.cnm.vnalo.moderation_service.exception.ApiException;
import iuh.cnm.vnalo.moderation_service.exception.ErrorCode;
import iuh.cnm.vnalo.moderation_service.model.entity.ModerationAuditLog;
import iuh.cnm.vnalo.moderation_service.repository.ModerationAuditLogRepository;
import iuh.cnm.vnalo.moderation_service.query.SharedUserQueryService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Regression guard tests to ensure critical bugs don't return:
 * - NPE from null principal in controller
 * - SQL grammar errors from schema joins
 * - JSONB serialization errors in audit logging
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class RegressionGuardIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private SharedUserQueryService sharedUserQueryService;

    @Autowired
    private ModerationAuditLogRepository auditLogRepository;

    // ============================================
    // NPE REGRESSION TESTS
    // ============================================

    @Test
    @WithMockUser(username = "22222222-2222-2222-2222-222222222222", roles = {"MODERATOR"})
    void moderationControllerWithMockUser_shouldNotThrowNPE() throws Exception {
        // Tests that controller doesn't throw NPE when resolving principal
        // Response may be 403 (permission denied) or 200, but NOT 500 or NPE
        var result = mockMvc.perform(get("/api/v1/moderation/reports"))
                .andReturn();
        
        int status = result.getResponse().getStatus();
        assertThat(status).isIn(200, 403);  // OK or Forbidden, not 500
    }

    @Test
    void unauthenticatedRequest_shouldReturn401_notNPE() throws Exception {
        mockMvc.perform(get("/api/v1/moderation/reports"))
                .andExpect(status().isUnauthorized());
    }

    // ============================================
    // SQL GRAMMAR & SCHEMA JOIN TESTS
    // ============================================

    @Test
    void sharedUserQueryService_withNonExistentUser_shouldThrowMeaningfulException() {
        UUID nonExistentUser = UUID.fromString("00000000-0000-0000-0000-000000000000");

        // This test verifies that the SQL query (with INNER JOIN) executes without
        // grammar errors, though it fails to find the user as expected
        assertThatThrownBy(() -> sharedUserQueryService.getUserSnapshotJson(nonExistentUser))
                .isInstanceOf(ApiException.class)
                .extracting(ex -> ((ApiException) ex).getErrorCode())
                .isEqualTo(ErrorCode.MODERATION_TARGET_NOT_FOUND);
    }

    @Test
    void sharedUserQueryService_joinQuery_shouldNotThrowSQLGrammarException() {
        UUID testUserId = UUID.randomUUID();

        // This tests that the INNER JOIN between user_profile and auth_account
        // doesn't have SQL grammar errors. The exception should be APPLICATION error
        // (not found), not database error
        assertThatThrownBy(() -> sharedUserQueryService.getUserSnapshotJson(testUserId))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining(ErrorCode.MODERATION_TARGET_NOT_FOUND.getMessage());
    }

    // ============================================
    // JSONB AUDIT LOG TESTS
    // ============================================

    @Test
    void auditLogService_withJSONBFields_shouldPersistCorrectly() {
        // Test that JSONB columns are properly handled by Hibernate/JDBC
        ModerationAuditLog auditLog = ModerationAuditLog.builder()
                .reportId(UUID.randomUUID())
                .caseId(UUID.randomUUID())
                .action("STATUS_CHANGE")
                .oldValueJson("{\"status\":\"OPEN\"}")
                .newValueJson("{\"status\":\"ASSIGNED\"}")
                .performedBy(UUID.randomUUID())
                .build();

        ModerationAuditLog saved = auditLogRepository.save(auditLog);
        assertThat(saved.getId()).isNotNull();

        // Verify JSONB values persisted correctly
        ModerationAuditLog retrieved = auditLogRepository.findById(saved.getId()).orElse(null);
        assertThat(retrieved).isNotNull();
        assertThat(retrieved.getOldValueJson()).contains("OPEN");
        assertThat(retrieved.getNewValueJson()).contains("ASSIGNED");
    }

    @Test
    void auditLogService_withComplexJSONBStructure_shouldHandleNestedObjects() {
        // Complex nested JSON structure to ensure JSONB serialization works
        String complexJson = """
                {
                    "reason": "HARASSMENT",
                    "severity": "HIGH",
                    "metadata": {
                        "reported_at": "2026-03-22T00:00:00Z",
                        "reporter_country": "VN"
                    },
                    "evidence": ["link1", "link2"]
                }
                """;

        ModerationAuditLog auditLog = ModerationAuditLog.builder()
                .reportId(UUID.randomUUID())
                .caseId(UUID.randomUUID())
                .action("REPORT_CREATED")
                .oldValueJson(null)
                .newValueJson(complexJson)
                .performedBy(UUID.randomUUID())
                .build();

        ModerationAuditLog saved = auditLogRepository.save(auditLog);

        ModerationAuditLog retrieved = auditLogRepository.findById(saved.getId()).orElse(null);
        assertThat(retrieved).isNotNull();
        assertThat(retrieved.getNewValueJson()).contains("HARASSMENT");
        assertThat(retrieved.getNewValueJson()).contains("HIGH");
        assertThat(retrieved.getNewValueJson()).contains("VN");
    }

    @Test
    void auditLogService_withNullJSONBFields_shouldPersistAsNull() {
        // Test that null JSONB fields are properly handled
        ModerationAuditLog auditLog = ModerationAuditLog.builder()
                .reportId(UUID.randomUUID())
                .caseId(UUID.randomUUID())
                .action("AUDIT_CLEANUP")
                .oldValueJson(null)
                .newValueJson(null)
                .performedBy(UUID.randomUUID())
                .build();

        ModerationAuditLog saved = auditLogRepository.save(auditLog);

        ModerationAuditLog retrieved = auditLogRepository.findById(saved.getId()).orElse(null);
        assertThat(retrieved).isNotNull();
        assertThat(retrieved.getOldValueJson()).isNull();
        assertThat(retrieved.getNewValueJson()).isNull();
    }
}

