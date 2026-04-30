import { API_BASE_URL } from '../api.client';

export function resolveMediaUrl(url?: string | null): string {
  if (!url) return '';

  if (url.startsWith('blob:')) {
    return url;
  }

  // Detect and handle AWS S3 URLs to bypass AccessDenied by using our Java Proxy
  if (url.includes('s3.amazonaws.com')) {
    try {
      const urlObj = new URL(url);
      // Object key is the path after the bucket name (e.g., /chat_image/...)
      const objectKey = urlObj.pathname.startsWith('/') ? urlObj.pathname.slice(1) : urlObj.pathname;
      
      // Mandatory: Detect category from key prefix for the Java Backend Proxy
      let category = 'CHAT_FILE';
      const lowerKey = objectKey.toLowerCase();
      if (lowerKey.startsWith('emoji/')) category = 'EMOJI';
      else if (lowerKey.startsWith('sticker/')) category = 'STICKER';
      else if (lowerKey.startsWith('chat_image/')) category = 'CHAT_IMAGE';
      else if (lowerKey.startsWith('chat_video/')) category = 'CHAT_VIDEO';
      else if (lowerKey.startsWith('avatar/')) category = 'AVATAR';
      else if (lowerKey.startsWith('cover/')) category = 'COVER';
      else if (lowerKey.startsWith('story/')) category = 'STORY';
      else if (lowerKey.startsWith('timeline/')) category = 'TIMELINE';

      // Use API_BASE_URL from api.client for reliability
      const base = (API_BASE_URL || '').replace(/\/api\/v1\/?$/, '');
      const finalBase = base || window.location.origin;
      return `${finalBase}/api/v1/media/public-file?key=${encodeURIComponent(objectKey)}&category=${category}`;
    } catch (e) {
      return url;
    }
  }

  // Handle absolute URLs (localhost/127.0.0.1)
  if (url.startsWith('http://') || url.startsWith('https://')) {
    const urlObj = new URL(url);
    if (urlObj.hostname === 'localhost' || urlObj.hostname === '127.0.0.1') {
      const base = (API_BASE_URL || '').replace(/\/api\/v1\/?$/, '');
      const finalBase = base || window.location.origin;
      return `${finalBase}${urlObj.pathname}${urlObj.search}`;
    }
    return url;
  }

  // Handle relative paths
  const relativePath = url.startsWith('/') ? url : `/${url}`;
  const base = (API_BASE_URL || '').replace(/\/api\/v1\/?$/, '');
  const finalBase = base || window.location.origin;
  return `${finalBase}${relativePath}`;
}
