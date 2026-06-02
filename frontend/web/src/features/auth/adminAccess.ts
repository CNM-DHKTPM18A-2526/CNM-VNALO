import type { AuthUser } from './auth.types'

const ADMIN_ROLE_KEYS = new Set([
  'ROLE_SUPER_ADMIN',
  'SUPER_ADMIN',
  'ROLE_ADMIN_MONITORING_VIEWER',
  'ADMIN_MONITORING_VIEWER',
  'ROLE_ADMIN_MONITORING_ANALYST',
  'ADMIN_MONITORING_ANALYST',
])

const ADMIN_PERMISSION_KEYS = new Set([
  'ADMIN_MONITORING_VIEW',
  'ADMIN_MONITORING_EXPORT',
  'ADMIN_MONITORING_RBAC_MANAGE',
])

type JwtClaims = {
  roles?: unknown
  authorities?: unknown
  permissions?: unknown
  scope?: unknown
  scp?: unknown
}

function normalizeValues(value: unknown): string[] {
  if (Array.isArray(value)) {
    return value.flatMap(normalizeValues)
  }

  if (typeof value === 'string') {
    return value
      .split(/[\s,]+/)
      .map((item) => item.trim())
      .filter(Boolean)
  }

  return []
}

function decodeJwtClaims(token: string | null | undefined): JwtClaims | null {
  if (!token) return null

  const [, payload] = token.split('.')
  if (!payload) return null

  try {
    const normalizedPayload = payload.replace(/-/g, '+').replace(/_/g, '/')
    const paddedPayload = normalizedPayload.padEnd(Math.ceil(normalizedPayload.length / 4) * 4, '=')
    const json = decodeURIComponent(
      Array.from(atob(paddedPayload))
        .map((char) => `%${char.charCodeAt(0).toString(16).padStart(2, '0')}`)
        .join(''),
    )
    return JSON.parse(json) as JwtClaims
  } catch {
    return null
  }
}

export function canAccessAdminMonitoring(user: AuthUser | null, accessToken?: string | null): boolean {
  const claims = decodeJwtClaims(accessToken)
  const roles = [
    ...normalizeValues(user?.roles),
    ...normalizeValues(claims?.roles),
    ...normalizeValues(claims?.authorities),
  ].map((role) => role.toUpperCase())
  const permissions = [
    ...normalizeValues(user?.permissions),
    ...normalizeValues(claims?.permissions),
    ...normalizeValues(claims?.scope),
    ...normalizeValues(claims?.scp),
  ].map((permission) => permission.toUpperCase())

  return roles.some((role) => ADMIN_ROLE_KEYS.has(role)) || permissions.some((permission) => ADMIN_PERMISSION_KEYS.has(permission))
}
