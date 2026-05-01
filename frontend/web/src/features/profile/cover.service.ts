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

export async function uploadCover(file: File, token: string): Promise<string> {
  const formData = new FormData()
  formData.append('file', file)
  formData.append('category', 'COVER')

  const response = await fetch(`${MEDIA_API_BASE_URL}upload`, {
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
