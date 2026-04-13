import type { ChatSticker } from './chat.types'

function toDataUri(svg: string): string {
  return `data:image/svg+xml;charset=UTF-8,${encodeURIComponent(svg)}`
}

function createSticker(label: string, accent: string, emoji: string): ChatSticker {
  const svg = `
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200" role="img" aria-label="${label}">
      <defs>
        <linearGradient id="bg" x1="0" x2="1" y1="0" y2="1">
          <stop offset="0%" stop-color="#fffdf7" />
          <stop offset="100%" stop-color="${accent}" stop-opacity="0.18" />
        </linearGradient>
      </defs>
      <rect width="200" height="200" rx="36" fill="url(#bg)" />
      <circle cx="100" cy="88" r="58" fill="${accent}" fill-opacity="0.18" />
      <text x="100" y="108" text-anchor="middle" font-size="64" font-family="system-ui, sans-serif">${emoji}</text>
      <text x="100" y="164" text-anchor="middle" font-size="16" font-weight="700" fill="#3d3d3d" font-family="system-ui, sans-serif">${label}</text>
    </svg>
  `.trim()

  return {
    id: label.toLowerCase().replace(/\s+/g, '-'),
    name: label,
    url: toDataUri(svg),
  }
}

export const DEFAULT_CHAT_STICKERS: ChatSticker[] = [
  createSticker('Xin chào', '#5b8def', '👋'),
  createSticker('Tuyệt quá', '#10b981', '✨'),
  createSticker('Cảm ơn', '#f59e0b', '🙏'),
  createSticker('Ổn áp', '#ef4444', '😎'),
  createSticker('Yêu thương', '#ec4899', '💛'),
  createSticker('Tạm biệt', '#8b5cf6', '👋'),
]