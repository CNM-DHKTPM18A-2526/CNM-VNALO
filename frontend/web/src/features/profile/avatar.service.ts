import { updateProfile } from '../auth/auth.api'
import type { AuthUser } from '../auth/auth.types'

// All services route through Nginx gateway at 13.250.2.132 on staging,
// but on local we use the direct media service port.
import { MEDIA_API_URL as MEDIA_API_BASE_URL, extractMessage } from '../../api.client';

type ApiResponse<T> = {
  data?: T
  message?: string
  error?: string
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

  const response = await fetch(`${MEDIA_API_BASE_URL}upload`, {
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
