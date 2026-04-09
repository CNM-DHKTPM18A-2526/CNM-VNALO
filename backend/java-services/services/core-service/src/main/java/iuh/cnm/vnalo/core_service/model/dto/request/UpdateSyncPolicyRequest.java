package iuh.cnm.vnalo.core_service.model.dto.request;

public record UpdateSyncPolicyRequest(
                Boolean syncEnabled,
                Boolean webRestrictedMode
) {
        public boolean hasAnyChange() {
                return syncEnabled != null || webRestrictedMode != null;
        }
}
