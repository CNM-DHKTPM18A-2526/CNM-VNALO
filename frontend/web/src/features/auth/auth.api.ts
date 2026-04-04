import type { AuthUser, LoginPayload } from './auth.types'

const API_BASE_URL = import.meta.env.VITE_CORE_API_URL ?? 'http://localhost:8081/api/v1'

type ApiResponse<T> = {
  data?: T
  message?: string
}

function normalizeIdentifier(identifier: string) {
  const trimmed = identifier.trim()

  if (!trimmed) {
    return trimmed
  }

  const compact = trimmed.replace(/[\s-]/g, '')

  if (/^0\d{9}$/.test(compact)) {
    return `+84${compact.slice(1)}`
  }

  return compact
}

function extractToken(payload: unknown): string | null {
  if (!payload || typeof payload !== 'object') {
    return null
  }

  const maybeObject = payload as Record<string, unknown>

  if (typeof maybeObject.accessToken === 'string') {
    return maybeObject.accessToken
  }

  if (typeof maybeObject.token === 'string') {
    return maybeObject.token
  }

  if (maybeObject.data && typeof maybeObject.data === 'object') {
    const nested = maybeObject.data as Record<string, unknown>

    if (typeof nested.accessToken === 'string') {
      return nested.accessToken
    }

    if (typeof nested.token === 'string') {
      return nested.token
    }
  }

  return null
}

function extractUser(payload: unknown): AuthUser | null {
  if (!payload || typeof payload !== 'object') {
    return null
  }

  const maybeResponse = payload as ApiResponse<Record<string, unknown>>
  const raw = maybeResponse.data ?? (payload as Record<string, unknown>)

  const id = typeof raw.id === 'string' ? raw.id : typeof raw.userId === 'string' ? raw.userId : ''
  const email = typeof raw.email === 'string' ? raw.email : ''

  const displayName =
    typeof raw.displayName === 'string'
      ? raw.displayName
      : typeof raw.name === 'string'
        ? raw.name
        : typeof raw.fullName === 'string'
          ? raw.fullName
          : email

  if (!id && !email) {
    return null
  }

  return {
    id: id || email,
    name: displayName || 'VNALO User',
    email,
  }
}

export async function login(payload: LoginPayload): Promise<string> {
  const normalizedPayload = {
    ...payload,
    identifier: normalizeIdentifier(payload.identifier),
  }

  const response = await fetch(`${API_BASE_URL}/auth/login`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(normalizedPayload),
  })

  const json = (await response.json().catch(() => null)) as unknown

  if (!response.ok) {
    throw new Error('Đăng nhập thất bại. Vui lòng kiểm tra tài khoản.')
  }

  const token = extractToken(json)

  if (!token) {
    throw new Error('Không lấy được access token từ phản hồi API.')
  }

  return token
}

export async function getMe(token: string): Promise<AuthUser> {
  const response = await fetch(`${API_BASE_URL}/users/me`, {
    headers: {
      Authorization: `Bearer ${token}`,
    },
  })

  const json = (await response.json().catch(() => null)) as unknown

  if (!response.ok) {
    throw new Error('Không lấy được thông tin người dùng.')
  }

  const user = extractUser(json)

  if (!user) {
    throw new Error('Phản hồi /users/me không hợp lệ.')
  }

  return user
}
