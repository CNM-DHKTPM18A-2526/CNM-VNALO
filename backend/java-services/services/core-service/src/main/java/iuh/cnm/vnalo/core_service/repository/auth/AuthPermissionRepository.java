package iuh.cnm.vnalo.core_service.repository.auth;

import iuh.cnm.vnalo.core_service.model.entity.auth.AuthAccount;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.Repository;
import org.springframework.data.repository.query.Param;

import java.util.UUID;

public interface AuthPermissionRepository extends Repository<AuthAccount, UUID> {

    @Query(value = """
            SELECT COUNT(*) > 0
            FROM auth_account_role ar
            JOIN auth_role r ON r.role_id = ar.role_id
            JOIN auth_role_permission rp ON rp.role_id = r.role_id
            JOIN auth_permission p ON p.permission_id = rp.permission_id
            WHERE ar.account_id = :accountId
              AND p.code = :permissionCode
              AND (ar.expires_at IS NULL OR ar.expires_at > NOW())
            """, nativeQuery = true)
    boolean accountHasPermission(
            @Param("accountId") UUID accountId,
            @Param("permissionCode") String permissionCode
    );
}