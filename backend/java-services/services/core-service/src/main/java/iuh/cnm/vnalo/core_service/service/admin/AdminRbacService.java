package iuh.cnm.vnalo.core_service.service.admin;

import iuh.cnm.vnalo.core_service.exception.ApiException;
import iuh.cnm.vnalo.core_service.exception.ErrorCode;
import iuh.cnm.vnalo.core_service.model.dto.request.admin.AdminRoleGrantRequest;
import iuh.cnm.vnalo.core_service.model.dto.request.admin.AdminRoleRevokeRequest;
import iuh.cnm.vnalo.core_service.model.dto.response.admin.AdminRoleAssignmentResponse;
import iuh.cnm.vnalo.core_service.repository.auth.AuthPermissionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AdminRbacService {
    public static final String PERMISSION_RBAC_MANAGE = "ADMIN_RBAC_MANAGE";

    private final AuthPermissionRepository authPermissionRepository;
    private final JdbcTemplate jdbcTemplate;

    @Transactional(readOnly = true)
    public List<AdminRoleAssignmentResponse> listAssignments(UUID requesterId) {
        assertCanManageRbac(requesterId);
        return jdbcTemplate.query("""
                SELECT a.id, a.email, r.code, ar.granted_at, ar.granted_by, ar.expires_at
                FROM auth_account_role ar
                JOIN auth_account a ON a.id = ar.account_id
                JOIN auth_role r ON r.role_id = ar.role_id
                ORDER BY ar.granted_at DESC, a.email ASC, r.code ASC
                """, (rs, rowNum) -> new AdminRoleAssignmentResponse(
                rs.getObject("id", UUID.class),
                rs.getString("email"),
                rs.getString("code"),
                rs.getTimestamp("granted_at").toInstant(),
                rs.getObject("granted_by", UUID.class),
                toInstant(rs.getTimestamp("expires_at"))
        ));
    }

    @Transactional
    public AdminRoleAssignmentResponse grantRole(UUID requesterId, AdminRoleGrantRequest request) {
        assertCanManageRbac(requesterId);
        String email = normalizeEmail(request.email());
        String roleCode = normalizeCode(request.roleCode());
        if (!StringUtils.hasText(email) || !StringUtils.hasText(roleCode)) {
            throw new ApiException(ErrorCode.VALIDATION_ERROR, "Email and role code are required");
        }
        UUID accountId = findAccountIdByEmail(email);
        UUID roleId = findRoleIdByCode(roleCode);
        Instant expiresAt = request.expiresAt();

        jdbcTemplate.update("""
                INSERT INTO auth_account_role (account_id, role_id, granted_at, granted_by, expires_at)
                VALUES (?, ?, NOW(), ?, ?)
                ON CONFLICT (account_id, role_id) DO UPDATE
                SET granted_by = EXCLUDED.granted_by,
                    expires_at = EXCLUDED.expires_at,
                    granted_at = NOW()
                """, accountId, roleId, requesterId, expiresAt == null ? null : Timestamp.from(expiresAt));
        return findAssignment(accountId, roleCode);
    }

    @Transactional
    public AdminRoleAssignmentResponse revokeRole(UUID requesterId, AdminRoleRevokeRequest request) {
        assertCanManageRbac(requesterId);
        String email = normalizeEmail(request.email());
        String roleCode = normalizeCode(request.roleCode());
        UUID accountId = findAccountIdByEmail(email);
        UUID roleId = findRoleIdByCode(roleCode);
        AdminRoleAssignmentResponse existing = findAssignment(accountId, roleCode);
        int deleted = jdbcTemplate.update("DELETE FROM auth_account_role WHERE account_id = ? AND role_id = ?", accountId, roleId);
        if (deleted == 0) {
            throw new ApiException(ErrorCode.RESOURCE_NOT_FOUND, "Role assignment not found");
        }
        return existing;
    }

    private void assertCanManageRbac(UUID requesterId) {
        if (requesterId == null || !authPermissionRepository.accountHasPermission(requesterId, PERMISSION_RBAC_MANAGE)) {
            throw new ApiException(ErrorCode.ACCESS_DENIED, "Admin RBAC management access denied");
        }
    }

    private UUID findAccountIdByEmail(String email) {
        List<UUID> ids = jdbcTemplate.query("SELECT id FROM auth_account WHERE LOWER(TRIM(email)) = ?", (rs, rowNum) -> rs.getObject("id", UUID.class), email);
        if (ids.isEmpty()) {
            throw new ApiException(ErrorCode.AUTH_ACCOUNT_NOT_FOUND_BY_EMAIL);
        }
        return ids.get(0);
    }

    private UUID findRoleIdByCode(String roleCode) {
        List<UUID> ids = jdbcTemplate.query("SELECT role_id FROM auth_role WHERE code = ?", (rs, rowNum) -> rs.getObject("role_id", UUID.class), roleCode);
        if (ids.isEmpty()) {
            throw new ApiException(ErrorCode.RESOURCE_NOT_FOUND, "Admin role not found");
        }
        return ids.get(0);
    }

    private AdminRoleAssignmentResponse findAssignment(UUID accountId, String roleCode) {
        List<AdminRoleAssignmentResponse> assignments = jdbcTemplate.query("""
                SELECT a.id, a.email, r.code, ar.granted_at, ar.granted_by, ar.expires_at
                FROM auth_account_role ar
                JOIN auth_account a ON a.id = ar.account_id
                JOIN auth_role r ON r.role_id = ar.role_id
                WHERE ar.account_id = ? AND r.code = ?
                """, (rs, rowNum) -> new AdminRoleAssignmentResponse(
                rs.getObject("id", UUID.class),
                rs.getString("email"),
                rs.getString("code"),
                rs.getTimestamp("granted_at").toInstant(),
                rs.getObject("granted_by", UUID.class),
                toInstant(rs.getTimestamp("expires_at"))
        ), accountId, roleCode);
        if (assignments.isEmpty()) {
            throw new ApiException(ErrorCode.RESOURCE_NOT_FOUND, "Role assignment not found");
        }
        return assignments.get(0);
    }

    private Instant toInstant(Timestamp timestamp) {
        return timestamp == null ? null : timestamp.toInstant();
    }

    private String normalizeEmail(String email) {
        return email == null ? "" : email.trim().toLowerCase(Locale.ROOT);
    }

    private String normalizeCode(String code) {
        return code == null ? "" : code.trim().toUpperCase(Locale.ROOT);
    }
}
