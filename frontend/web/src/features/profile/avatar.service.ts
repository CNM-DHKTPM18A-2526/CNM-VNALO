import { updateProfile } from '../auth/auth.api'
import type { AuthUser } from '../auth/auth.types'

const MEDIA_API_BASE_URL = import.meta.env.VITE_MEDIA_API_URL ?? 'http://localhost:8083/api/v1'

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

  return null
}

function extractMediaUrl(payload: unknown): string | null {
  if (!payload || typeof payload !== 'object') {
    return null
  }

  const maybeResponse = payload as ApiResponse<Record<string, unknown>>
  const raw = maybeResponse.data ?? (payload as Record<string, unknown>)

  if (typeof raw.url === 'string' && raw.url.trim()) {
    return raw.url
  }

  return null
}

async function uploadAvatarToMedia(token: string, file: File): Promise<string> {
  const formData = new FormData()
  formData.append('file', file)
  formData.append('category', 'AVATAR')

  const response = await fetch(`${MEDIA_API_BASE_URL}/media/upload`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
    },
    body: formData,
  })

  const json = (await response.json().catch(() => null)) as unknown

  if (!response.ok) {
    throw new Error(extractMessage(json) ?? 'Không thể tải ảnh đại diện lên.')
  }

  const mediaUrl = extractMediaUrl(json)

  if (!mediaUrl) {
    throw new Error('Phản hồi upload ảnh không hợp lệ.')
  }

  return mediaUrl
}

export async function updateAvatarForUser(token: string, file: File): Promise<AuthUser> {
  const avatarUrl = await uploadAvatarToMedia(token, file)
  return updateProfile(token, { avatarUrl })
}
