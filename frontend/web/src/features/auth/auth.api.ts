import { normalizeVietnamPhone } from './phone.util'
import type { AuthUser, Gender, LoginPayload, RegisterPayload, SendRegisterOtpPayload } from './auth.types'

const API_BASE_URL = import.meta.env.VITE_CORE_API_URL ?? 'http://localhost:8081/api/v1'

export type UpdateProfilePayload = {
  displayName?: string
  avatarUrl?: string
  coverUrl?: string
  bio?: string
  dob?: string
  gender?: Gender
}

export type ForgotPasswordSendOtpPayload = {
  email: string
}

export type ResetPasswordPayload = {
  email: string
  otp: string
  newPassword: string
}

export type ChangePasswordPayload = {
  currentPassword: string
  newPassword: string
}

export type SyncPolicy = {
  syncEnabled: boolean
  webRestrictedMode: boolean
}

export type QrLoginSession = {
  token: string
  qrPayload: string
  expiresAt: string
  expiresInSeconds: number
}

export type QrLoginPollResult = {
  status: string
  accessToken?: string
}

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

const WEB_DEVICE_STORAGE_KEY = 'vnalo.web.deviceId'

function resolveWebDeviceId(): string {
  const stored = window.localStorage.getItem(WEB_DEVICE_STORAGE_KEY)
  if (stored && stored.trim().length > 0) {
    return stored
  }

  const generated =
    typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function'
      ? `web-${crypto.randomUUID()}`
      : `web-${Date.now()}-${Math.random().toString(16).slice(2)}`
  window.localStorage.setItem(WEB_DEVICE_STORAGE_KEY, generated)
  return generated
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

    if (nested.auth && typeof nested.auth === 'object') {
      const auth = nested.auth as Record<string, unknown>
      if (typeof auth.accessToken === 'string') {
        return auth.accessToken
      }
    }
  }

  return null
}

function isGender(value: unknown): value is Gender {
  return value === 'MALE' || value === 'FEMALE' || value === 'OTHER'
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
    phone: typeof raw.phone === 'string' ? raw.phone : null,
    avatarUrl: typeof raw.avatarUrl === 'string' ? raw.avatarUrl : null,
    coverUrl: typeof raw.coverUrl === 'string' ? raw.coverUrl : null,
    bio: typeof raw.bio === 'string' ? raw.bio : null,
    dob: typeof raw.dob === 'string' ? raw.dob : null,
    gender: isGender(raw.gender) ? raw.gender : null,
  }
}

export async function login(payload: LoginPayload): Promise<string> {
  const deviceId = payload.deviceId ?? resolveWebDeviceId()
  const normalizedPayload = {
    ...payload,
    identifier: normalizeIdentifier(payload.identifier),
    deviceId,
    deviceName: payload.deviceName ?? 'VNALO Web',
    platform: payload.platform ?? 'WEB',
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

export async function updateProfile(token: string, payload: UpdateProfilePayload): Promise<AuthUser> {
  const response = await fetch(`${API_BASE_URL}/users/me`, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  })

  const json = (await response.json().catch(() => null)) as unknown

  if (!response.ok) {
    throw new Error(extractMessage(json) ?? 'Không thể cập nhật hồ sơ người dùng.')
  }

  const user = extractUser(json)

  if (!user) {
    throw new Error('Phản hồi cập nhật hồ sơ không hợp lệ.')
  }

  return user
}

export async function sendRegisterOtp(payload: SendRegisterOtpPayload): Promise<void> {
  const normalizedPhone = normalizeVietnamPhone(payload.phone)
  const normalizedEmail = payload.email.trim().toLowerCase()

  const response = await fetch(`${API_BASE_URL}/auth/register/send-otp`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      phone: normalizedPhone,
      email: normalizedEmail,
    }),
  })

  const json = (await response.json().catch(() => null)) as unknown

  if (!response.ok) {
    throw new Error(extractMessage(json) ?? 'Không thể gửi OTP. Vui lòng thử lại.')
  }
}

export async function register(payload: RegisterPayload): Promise<string> {
  const normalizedEmail = payload.email.trim().toLowerCase()

  const response = await fetch(`${API_BASE_URL}/auth/register`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      displayName: payload.displayName,
      password: payload.password,
      phone: normalizeVietnamPhone(payload.phone),
      email: normalizedEmail,
      otp: payload.otpCode,
      dob: payload.dob,
      gender: payload.gender,
    }),
  })

  const json = (await response.json().catch(() => null)) as unknown

  if (!response.ok) {
    throw new Error(extractMessage(json) ?? 'Đăng ký thất bại. Vui lòng thử lại.')
  }

  const token = extractToken(json)

  if (!token) {
    throw new Error('Không lấy được access token từ phản hồi đăng ký.')
  }

  return token
}

export async function sendForgotPasswordOtp(payload: ForgotPasswordSendOtpPayload): Promise<void> {
  const normalizedEmail = payload.email.trim().toLowerCase()

  const response = await fetch(`${API_BASE_URL}/auth/forgot-password`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      email: normalizedEmail,
    }),
  })

  const json = (await response.json().catch(() => null)) as unknown

  if (!response.ok) {
    throw new Error(extractMessage(json) ?? 'Không thể gửi OTP khôi phục mật khẩu. Vui lòng thử lại.')
  }
}

export async function resetPassword(payload: ResetPasswordPayload): Promise<void> {
  const response = await fetch(`${API_BASE_URL}/auth/reset-password`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      email: payload.email.trim().toLowerCase(),
      otp: payload.otp,
      newPassword: payload.newPassword,
    }),
  })

  const json = (await response.json().catch(() => null)) as unknown

  if (!response.ok) {
    throw new Error(extractMessage(json) ?? 'Không thể đặt lại mật khẩu. Vui lòng thử lại.')
  }
}

export async function changePassword(token: string, payload: ChangePasswordPayload): Promise<void> {
  const response = await fetch(`${API_BASE_URL}/auth/password/change`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  })

  const json = (await response.json().catch(() => null)) as unknown

  if (!response.ok) {
    throw new Error(extractMessage(json) ?? 'Không thể đổi mật khẩu. Vui lòng thử lại.')
  }
}

function extractSyncPolicy(payload: unknown): SyncPolicy | null {
  if (!payload || typeof payload !== 'object') {
    return null
  }

  const root = payload as Record<string, unknown>
  const maybeData = root.data && typeof root.data === 'object' ? (root.data as Record<string, unknown>) : root
  const syncEnabled = maybeData.syncEnabled
  const webRestrictedMode = maybeData.webRestrictedMode

  if (typeof syncEnabled !== 'boolean' || typeof webRestrictedMode !== 'boolean') {
    return null
  }

  return {
    syncEnabled,
    webRestrictedMode,
  }
}

export async function getSyncPolicy(token: string): Promise<SyncPolicy> {
  const response = await fetch(`${API_BASE_URL}/users/me/settings/sync`, {
    headers: {
      Authorization: `Bearer ${token}`,
    },
  })

  const json = (await response.json().catch(() => null)) as unknown

  if (!response.ok) {
    throw new Error(extractMessage(json) ?? 'Không lấy được chính sách đồng bộ.')
  }

  const policy = extractSyncPolicy(json)
  if (!policy) {
    throw new Error('Phản hồi sync policy không hợp lệ.')
  }

  return policy
}

function extractQrSession(payload: unknown): QrLoginSession | null {
  if (!payload || typeof payload !== 'object') {
    return null
  }

  const root = payload as Record<string, unknown>
  const data = root.data && typeof root.data === 'object' ? (root.data as Record<string, unknown>) : root

  if (
    typeof data.token !== 'string' ||
    typeof data.qrPayload !== 'string' ||
    typeof data.expiresAt !== 'string' ||
    typeof data.expiresInSeconds !== 'number'
  ) {
    return null
  }

  return {
    token: data.token,
    qrPayload: data.qrPayload,
    expiresAt: data.expiresAt,
    expiresInSeconds: data.expiresInSeconds,
  }
}

export async function createQrLoginSession(): Promise<QrLoginSession> {
  const response = await fetch(`${API_BASE_URL}/auth/qr/sessions`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      deviceName: 'VNALO Web',
      platform: 'WEB',
    }),
  })

  const json = (await response.json().catch(() => null)) as unknown

  if (!response.ok) {
    throw new Error(extractMessage(json) ?? 'Không thể tạo phiên đăng nhập QR.')
  }

  const session = extractQrSession(json)
  if (!session) {
    throw new Error('Phản hồi phiên QR không hợp lệ.')
  }

  return session
}

export async function pollQrLoginSession(token: string): Promise<QrLoginPollResult> {
  const response = await fetch(`${API_BASE_URL}/auth/qr/sessions/${encodeURIComponent(token)}`)
  const json = (await response.json().catch(() => null)) as unknown

  if (!response.ok) {
    throw new Error(extractMessage(json) ?? 'Không thể kiểm tra trạng thái QR login.')
  }

  const root = (json ?? {}) as Record<string, unknown>
  const data = root.data && typeof root.data === 'object' ? (root.data as Record<string, unknown>) : root

  return {
    status: typeof data.status === 'string' ? data.status : 'UNKNOWN',
    accessToken: extractToken(json) ?? undefined,
  }
}
