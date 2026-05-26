export type CameraDevice = {
  deviceId: string
  label: string
}

export type CameraState =
  | 'idle'
  | 'requesting'
  | 'active'
  | 'capturing'
  | 'error'
  | 'stopped'

const MAX_IMAGE_SIZE = 10 * 1024 * 1024 // 10MB

export async function getCameras(): Promise<CameraDevice[]> {
  const devices = await navigator.mediaDevices.enumerateDevices()
  return devices
    .filter((d) => d.kind === 'videoinput')
    .map((d) => ({
      deviceId: d.deviceId,
      label: d.label || `Camera ${d.deviceId.slice(0, 8)}`,
    }))
}

export async function createCameraStream(
  constraints?: MediaTrackConstraints,
): Promise<MediaStream | null> {
  if (!navigator.mediaDevices?.getUserMedia) {
    return null
  }

  const defaultConstraints: MediaStreamConstraints = {
    video: {
      facingMode: 'user',
      width: { ideal: 640 },
      height: { ideal: 480 },
      ...constraints,
    },
    audio: false,
  }

  try {
    const stream = await navigator.mediaDevices.getUserMedia(defaultConstraints)
    return stream
  } catch {
    return null
  }
}

export async function captureFrame(video: HTMLVideoElement): Promise<Blob | null> {
  if (!video.videoWidth || !video.videoHeight) {
    return null
  }

  const canvas = document.createElement('canvas')
  canvas.width = video.videoWidth
  canvas.height = video.videoHeight

  const ctx = canvas.getContext('2d')
  if (!ctx) {
    return null
  }

  ctx.drawImage(video, 0, 0)

  return new Promise((resolve) => {
    canvas.toBlob(
      (blob) => {
        if (blob && blob.size > MAX_IMAGE_SIZE) {
          resolve(compressToSize(canvas, MAX_IMAGE_SIZE))
        } else {
          resolve(blob)
        }
      },
      'image/jpeg',
      0.92,
    )
  })
}

async function compressToSize(canvas: HTMLCanvasElement, maxSize: number): Promise<Blob | null> {
  let quality = 0.92
  let blob: Blob | null = null

  while (quality > 0.1) {
    blob = await new Promise<Blob | null>((r) =>
      canvas.toBlob((b) => r(b), 'image/jpeg', quality),
    )

    if (blob && blob.size <= maxSize) {
      return blob
    }

    quality -= 0.1
  }

  return blob
}

export function stopCameraStream(stream: MediaStream | null) {
  if (!stream) return

  stream.getTracks().forEach((track) => {
    track.stop()
  })
}

export async function requestCameraPermission(): Promise<boolean> {
  if (!navigator.mediaDevices?.getUserMedia) {
    return false
  }

  try {
    const stream = await navigator.mediaDevices.getUserMedia({ video: true, audio: false })
    stream.getTracks().forEach((track) => track.stop())
    return true
  } catch {
    return false
  }
}

export function getCameraErrorMessage(error: unknown): string {
  if (error instanceof DOMException) {
    switch (error.name) {
      case 'NotAllowedError':
        return 'Quyền truy cập camera bị từ chối. Vui lòng cho phép truy cập camera trong cài đặt trình duyệt.'
      case 'NotFoundError':
        return 'Không tìm thấy camera. Vui lòng kết nối camera và thử lại.'
      case 'NotReadableError':
        return 'Camera đang được sử dụng bởi ứng dụng khác. Vui lòng đóng ứng dụng khác và thử lại.'
      case 'OverconstrainedError':
        return 'Camera không hỗ trợ yêu cầu chất lượng hình ảnh.'
      default:
        return `Lỗi camera: ${error.message}`
    }
  }

  if (error instanceof Error) {
    return error.message
  }

  return 'Không thể truy cập camera. Vui lòng thử lại.'
}
