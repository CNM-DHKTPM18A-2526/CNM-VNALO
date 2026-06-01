CREATE TABLE IF NOT EXISTS auth_role (
    role_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(80) NOT NULL UNIQUE,
    name VARCHAR(120) NOT NULL,
    description VARCHAR(500),
    system_role BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS auth_permission (
    permission_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(120) NOT NULL UNIQUE,
    name VARCHAR(160) NOT NULL,
    description VARCHAR(500),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS auth_role_permission (
    role_id UUID NOT NULL,
    permission_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    PRIMARY KEY (role_id, permission_id),
    CONSTRAINT fk_auth_role_permission_role
        FOREIGN KEY (role_id) REFERENCES auth_role(role_id) ON DELETE CASCADE,
    CONSTRAINT fk_auth_role_permission_permission
        FOREIGN KEY (permission_id) REFERENCES auth_permission(permission_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS auth_account_role (
    account_id UUID NOT NULL,
    role_id UUID NOT NULL,
    granted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    granted_by UUID,
    expires_at TIMESTAMP WITH TIME ZONE,
    PRIMARY KEY (account_id, role_id),
    CONSTRAINT fk_auth_account_role_account
        FOREIGN KEY (account_id) REFERENCES auth_account(id) ON DELETE CASCADE,
    CONSTRAINT fk_auth_account_role_role
        FOREIGN KEY (role_id) REFERENCES auth_role(role_id) ON DELETE CASCADE,
    CONSTRAINT fk_auth_account_role_granted_by
        FOREIGN KEY (granted_by) REFERENCES auth_account(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_auth_account_role_role
    ON auth_account_role(role_id);

CREATE INDEX IF NOT EXISTS idx_auth_account_role_expires_at
    ON auth_account_role(expires_at);

INSERT INTO auth_permission (code, name, description)
VALUES
    ('ADMIN_MONITORING_VIEW', 'View admin monitoring', 'View metadata-only monitoring dashboard, counters, and trends.'),
    ('ADMIN_MONITORING_EXPORT', 'Export admin monitoring', 'Export monitoring event metadata for operational review.'),
    ('ADMIN_RBAC_MANAGE', 'Manage admin RBAC', 'Grant and revoke administrative roles and permissions.')
ON CONFLICT (code) DO UPDATE
SET name = EXCLUDED.name,
    description = EXCLUDED.description,
    updated_at = NOW();

INSERT INTO auth_role (code, name, description, system_role)
VALUES
    ('ADMIN_MONITORING_VIEWER', 'Admin monitoring viewer', 'Can view VNALO admin monitoring dashboard.', TRUE),
    ('ADMIN_MONITORING_ANALYST', 'Admin monitoring analyst', 'Can view and export VNALO admin monitoring data.', TRUE),
    ('SUPER_ADMIN', 'Super admin', 'Can manage administrative permissions and access all admin monitoring features.', TRUE)
ON CONFLICT (code) DO UPDATE
SET name = EXCLUDED.name,
    description = EXCLUDED.description,
    system_role = EXCLUDED.system_role,
    updated_at = NOW();

INSERT INTO auth_role_permission (role_id, permission_id)
SELECT r.role_id, p.permission_id
FROM auth_role r
JOIN auth_permission p ON p.code = 'ADMIN_MONITORING_VIEW'
WHERE r.code IN ('ADMIN_MONITORING_VIEWER', 'ADMIN_MONITORING_ANALYST', 'SUPER_ADMIN')
ON CONFLICT DO NOTHING;

INSERT INTO auth_role_permission (role_id, permission_id)
SELECT r.role_id, p.permission_id
FROM auth_role r
JOIN auth_permission p ON p.code = 'ADMIN_MONITORING_EXPORT'
WHERE r.code IN ('ADMIN_MONITORING_ANALYST', 'SUPER_ADMIN')
ON CONFLICT DO NOTHING;

INSERT INTO auth_role_permission (role_id, permission_id)
SELECT r.role_id, p.permission_id
FROM auth_role r
JOIN auth_permission p ON p.code = 'ADMIN_RBAC_MANAGE'
WHERE r.code = 'SUPER_ADMIN'
ON CONFLICT DO NOTHING;