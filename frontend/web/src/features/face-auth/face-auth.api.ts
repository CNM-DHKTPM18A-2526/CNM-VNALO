import { API_BASE_URL } from '../../api.client'
import type {
  FaceEnrollmentResponse,
  FaceVerifyResponse,
  FaceStatusResponse,
  FaceLivenessResult,
  FaceHealthResponse,
} from './face-auth.types'

type ApiResponse<T> = {
  success: boolean
  data?: T
  message?: string
}

/** Races a promise against a timeout, rejecting with a user-friendly message on timeout. */
export function withTimeout<T>(promise: Promise<T>, ms: number, label: string): Promise<T> {
  return Promise.race([
    promise,
    new Promise<never>((_, reject) =>
      setTimeout(
        () => reject(new Error(`${label} quá thời gian chờ (${ms / 1000}s). Vui lòng kiểm tra kết nối và thử lại.`)),
        ms
      )
    ),
  ]);
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

  return null
}

async function fetchWithAuth(token: string, input: RequestInfo, init?: RequestInit): Promise<Response> {
  const headers = init?.headers
    ? new Headers(init.headers)
    : new Headers()

  if (!headers.has('Authorization')) {
    headers.set('Authorization', `Bearer ${token}`)
  }

  return fetch(input, {
    ...init,
    headers,
  })
}

export async function getFaceStatus(token: string): Promise<FaceStatusResponse> {
  const response = await fetchWithAuth(token, `${API_BASE_URL}/face/status`)

  const json = (await response.json().catch(() => null)) as unknown

  if (!response.ok) {
    const message = extractMessage(json)
    if (message) {
      throw new Error(message)
    }
    throw new Error('Không thể lấy trạng thái face auth.')
  }

  const root = json as ApiResponse<Record<string, unknown>>
  const data = root.data ?? {}

  return {
    enrolled: typeof data.enrolled === 'boolean' ? data.enrolled : false,
    enrolledAt: typeof data.enrolledAt === 'string' ? data.enrolledAt : null,
    version: typeof data.version === 'number' ? data.version : null,
    errorCode: typeof data.errorCode === 'string' ? data.errorCode : null,
    message: typeof data.message === 'string' ? data.message : null,
  }
}

export async function enrollFace(
  token: string,
  imageBlob: Blob,
  options?: {
    deviceInfo?: string
  },
): Promise<FaceEnrollmentResponse> {
  const formData = new FormData()
  formData.append('image', imageBlob, 'face.jpg')

  if (options?.deviceInfo) {
    formData.append('deviceInfo', options.deviceInfo)
  }

  const response = await fetchWithAuth(token, `${API_BASE_URL}/face/enroll`, {
    method: 'POST',
    body: formData,
  })

  const json = (await response.json().catch(() => null)) as unknown

  if (!response.ok) {
    const message = extractMessage(json)
    throw new Error(message ?? 'Đăng ký khuôn mặt thất bại.')
  }

  const root = json as ApiResponse<Record<string, unknown>>
  const data = root.data ?? {}

  return {
    success: typeof data.success === 'boolean' ? data.success : false,
    enrolledAt: typeof data.enrolledAt === 'string' ? data.enrolledAt : null,
    livenessScore: typeof data.livenessScore === 'number' ? data.livenessScore : null,
    version: typeof data.version === 'number' ? data.version : null,
    errorCode: typeof data.errorCode === 'string' ? data.errorCode : null,
    message: typeof data.message === 'string' ? data.message : null,
  }
}

export async function deleteFaceEnrollment(token: string): Promise<void> {
  const response = await fetchWithAuth(token, `${API_BASE_URL}/face/enrollment`, {
    method: 'DELETE',
  })

  const json = (await response.json().catch(() => null)) as unknown

  if (!response.ok) {
    const message = extractMessage(json)
    throw new Error(message ?? 'Không thể xóa face enrollment.')
  }
}

export async function verifyFace(
  imageBlob: Blob,
  userId: string,
): Promise<FaceVerifyResponse> {
  const formData = new FormData()
  formData.append('image', imageBlob, 'face.jpg')
  formData.append('userId', userId)

  const response = await fetch(`${API_BASE_URL}/face/verify`, {
    method: 'POST',
    body: formData,
  })

  const json = (await response.json().catch(() => null)) as unknown

  if (!response.ok) {
    const message = extractMessage(json)
    throw new Error(message ?? 'Xác thực khuôn mặt thất bại.')
  }

  const root = json as ApiResponse<Record<string, unknown>>
  const data = root.data ?? {}

  return {
    verified: typeof data.verified === 'boolean' ? data.verified : false,
    confidence: typeof data.confidence === 'number' ? data.confidence : null,
    threshold: typeof data.threshold === 'number' ? data.threshold : null,
    decision: typeof data.decision === 'string' ? data.decision : null,
    inferenceTimeMs: typeof data.inferenceTimeMs === 'number' ? data.inferenceTimeMs : null,
    errorCode: typeof data.errorCode === 'string' ? data.errorCode : null,
    message: typeof data.message === 'string' ? data.message : null,
    verificationToken: typeof data.verificationToken === 'string' ? data.verificationToken : null,
  }
}

export async function faceLogin(
  verificationToken: string,
  deviceId: string,
  deviceName: string,
  platform: string,
): Promise<{ accessToken: string; refreshToken: string }> {
  const response = await fetch(`${API_BASE_URL}/auth/face-login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ verificationToken, deviceId, deviceName, platform }),
  })

  const json = (await response.json().catch(() => null)) as unknown

  if (!response.ok) {
    const message = extractMessage(json)
    throw new Error(message ?? 'Đăng nhập bằng khuôn mặt thất bại.')
  }

  const root = json as ApiResponse<Record<string, unknown>>
  const data = root.data ?? {}

  const accessToken = typeof data.accessToken === 'string' ? data.accessToken : ''
  const refreshToken = typeof data.refreshToken === 'string' ? data.refreshToken : ''

  if (!accessToken || !refreshToken) {
    throw new Error('Không lấy được token từ phản hồi.')
  }

  return { accessToken, refreshToken }
}

export async function checkLiveness(imageBlob: Blob): Promise<FaceLivenessResult> {
  const formData = new FormData()
  formData.append('image', imageBlob, 'face.jpg')

  const response = await fetch(`${API_BASE_URL}/face/liveness-check`, {
    method: 'POST',
    body: formData,
  })

  const json = (await response.json().catch(() => null)) as unknown

  if (!response.ok) {
    const message = extractMessage(json)
    throw new Error(message ?? 'Kiểm tra liveness thất bại.')
  }

  const root = json as ApiResponse<Record<string, unknown>>
  const data = root.data ?? {}

  return {
    isLive: typeof data.isLive === 'boolean' ? data.isLive : false,
    score: typeof data.score === 'number' ? data.score : 0,
    threshold: typeof data.threshold === 'number' ? data.threshold : 0,
    pass: typeof data.pass === 'boolean' ? data.pass : false,
  }
}

export async function lookupUserId(identifier: string): Promise<string> {
  const response = await fetch(
    `${API_BASE_URL}/auth/lookup?identifier=${encodeURIComponent(identifier)}`
  )

  const json = (await response.json().catch(() => null)) as unknown

  if (!response.ok) {
    const message = extractMessage(json)
    throw new Error(message ?? 'Không tìm thấy tài khoản.')
  }

  const root = json as ApiResponse<Record<string, unknown>>
  const data = root.data ?? {}

  const userId = typeof data.userId === 'string' ? data.userId : ''
  if (!userId) {
    throw new Error('Không tìm thấy tài khoản.')
  }

  return userId
}

export async function getFaceHealth(): Promise<FaceHealthResponse> {
  const response = await fetch(`${API_BASE_URL}/face/health`)

  const json = (await response.json().catch(() => null)) as unknown

  if (!response.ok) {
    return {
      enabled: false,
      modelReady: false,
      timestamp: new Date().toISOString(),
    }
  }

  const root = json as ApiResponse<Record<string, unknown>>
  const data = root.data ?? {}

  return {
    enabled: typeof data.enabled === 'boolean' ? data.enabled : false,
    modelReady: typeof data.modelReady === 'boolean' ? data.modelReady : false,
    timestamp: typeof data.timestamp === 'string' ? data.timestamp : new Date().toISOString(),
  }
}
