// All services route through Nginx gateway at 13.250.2.132
const MEDIA_API_BASE_URL = import.meta.env.VITE_MEDIA_API_URL ?? 'http://13.250.2.132/api/v1'

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

export async function uploadCover(file: File, token: string): Promise<string> {
  const formData = new FormData()
  formData.append('file', file)
  formData.append('category', 'COVER')

  const response = await fetch(`${MEDIA_API_BASE_URL}/media/upload`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
    },
    body: formData,
  })

  const json = (await response.json().catch(() => null)) as unknown

  if (!response.ok) {
    throw new Error(extractMessage(json) ?? 'Không thể tải ảnh bìa lên.')
  }

  const mediaUrl = extractMediaUrl(json)

  if (!mediaUrl) {
    throw new Error('Phản hồi upload ảnh bìa không hợp lệ.')
  }

  return mediaUrl
}
