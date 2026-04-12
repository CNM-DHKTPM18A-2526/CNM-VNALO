/**
 * Format presence status thành tiếng Việt.
 * Online luôn được ưu tiên tuyệt đối, chỉ khi offline mới dùng lastSeenTime.
 */
export function formatPresence(isOnline?: boolean | null, lastSeenTime?: string | null): string {
  if (isOnline === true) {
    return 'Đang hoạt động'
  }

  if (!lastSeenTime) {
    return 'Ngoại tuyến'
  }

  try {
    const lastSeen = new Date(lastSeenTime)
    const now = new Date()
    const diffMs = now.getTime() - lastSeen.getTime()
    const diffMinutes = Math.floor(diffMs / (1000 * 60))
    const diffHours = Math.floor(diffMs / (1000 * 60 * 60))
    const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24))

    if (diffMinutes < 1) {
      return 'Vừa mới truy cập'
    }

    if (diffMinutes < 60) {
      return `${diffMinutes} phút trước`
    }

    if (diffHours < 24) {
      return `${diffHours} giờ trước`
    }

    if (diffDays === 1) {
      return 'Hôm qua'
    }

    if (diffDays < 7) {
      return `${diffDays} ngày trước`
    }

    return new Intl.DateTimeFormat('vi-VN', {
      weekday: 'long',
      month: 'numeric',
      day: 'numeric',
    }).format(lastSeen)
  } catch (error) {
    console.warn('[formatPresence] Invalid date:', lastSeenTime)
    return 'Ngoại tuyến'
  }
}
