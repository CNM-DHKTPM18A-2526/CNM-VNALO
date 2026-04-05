import { normalizeVietnamPhone } from './phone.util'
import type { AuthUser, LoginPayload, RegisterPayload, SendRegisterOtpPayload } from './auth.types'

const API_BASE_URL = import.meta.env.VITE_CORE_API_URL ?? 'http://localhost:8081/api/v1'

type ApiResponse<T> = {
  data?: T
  message?: string
  error?: string
}

function extractMessage(payload: unknown): string | null {
  if (!payload || typeof payload !== 'object') {
    return null
  }

  const obj = payload as Record<string, unknown>

  if (typeof obj.message === 'string' && obj.message.trim()) {
    return obj.message
  }

  if (typeof obj.error === 'string' && obj.error.trim()) {
    return obj.error
  }

  if (obj.data && typeof obj.data === 'object') {
    const nested = obj.data as Record<string, unknown>

    if (typeof nested.message === 'string' && nested.message.trim()) {
      return nested.message
    }
  }

  if (Array.isArray(obj.errors) && obj.errors.length > 0) {
    const firstError = obj.errors[0]

    if (typeof firstError === 'string' && firstError.trim()) {
      return firstError
    }

    if (firstError && typeof firstError === 'object') {
      const errorObj = firstError as Record<string, unknown>
      if (typeof errorObj.message === 'string' && errorObj.message.trim()) {
        return errorObj.message
      }
      if (typeof errorObj.defaultMessage === 'string' && errorObj.defaultMessage.trim()) {
        return errorObj.defaultMessage
      }
    }
  }

  return null
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
    throw new Error(extractMessage(json) ?? 'Đăng nhập thất bại. Vui lòng kiểm tra tài khoản.')
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
    throw new Error(extractMessage(json) ?? 'Không lấy được thông tin người dùng.')
  }

  const user = extractUser(json)

  if (!user) {
    throw new Error('Phản hồi /users/me không hợp lệ.')
  }

  return user
}

export async function sendRegisterOtp(payload: SendRegisterOtpPayload): Promise<void> {
  const normalizedPhone = normalizeVietnamPhone(payload.phone)

  const response = await fetch(`${API_BASE_URL}/auth/register/send-otp`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      phone: normalizedPhone,
    }),
  })

  const json = (await response.json().catch(() => null)) as unknown

  if (!response.ok) {
    throw new Error(extractMessage(json) ?? 'Không thể gửi OTP. Vui lòng thử lại.')
  }
}

export async function register(payload: RegisterPayload): Promise<void> {
  const response = await fetch(`${API_BASE_URL}/auth/register`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      ...payload,
      phone: normalizeVietnamPhone(payload.phone),
    }),
  })

  const json = (await response.json().catch(() => null)) as unknown

  if (!response.ok) {
    throw new Error(extractMessage(json) ?? 'Đăng ký thất bại. Vui lòng thử lại.')
  }
}
