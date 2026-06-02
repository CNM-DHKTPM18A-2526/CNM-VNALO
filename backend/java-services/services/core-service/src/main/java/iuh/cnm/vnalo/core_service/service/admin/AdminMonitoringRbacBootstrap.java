package iuh.cnm.vnalo.core_service.service.admin;

import iuh.cnm.vnalo.core_service.config.AdminMonitoringProperties;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Locale;

@Component
@RequiredArgsConstructor
@Slf4j
public class AdminMonitoringRbacBootstrap {
    private static final String DEFAULT_BOOTSTRAP_ROLE = "SUPER_ADMIN";

    private final AdminMonitoringProperties adminMonitoringProperties;
    private final JdbcTemplate jdbcTemplate;

    @PostConstruct
    @Transactional
    public void bootstrap() {
        List<String> emails = adminMonitoringProperties.bootstrapEmails();
        if (emails == null || emails.isEmpty()) {
            return;
        }
        for (String email : emails) {
            String normalized = normalizeEmail(email);
            if (normalized.isBlank()) {
                continue;
            }
            int updated = jdbcTemplate.update("""
                    INSERT INTO auth_account_role (account_id, role_id, granted_at, granted_by, expires_at)
                    SELECT a.id, r.role_id, NOW(), NULL, NULL
                    FROM auth_account a
                    JOIN auth_role r ON r.code = ?
                    WHERE LOWER(TRIM(a.email)) = ?
                    ON CONFLICT (account_id, role_id) DO NOTHING
                    """, DEFAULT_BOOTSTRAP_ROLE, normalized);
            if (updated > 0) {
                log.info("Bootstrapped admin RBAC role {} for {}", DEFAULT_BOOTSTRAP_ROLE, normalized);
            }
        }
    }

    private String normalizeEmail(String email) {
        return email == null ? "" : email.trim().toLowerCase(Locale.ROOT);
    }
}