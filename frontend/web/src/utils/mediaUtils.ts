import { WS_BASE_URL } from '../api.client';

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
      return `${window.location.origin}/api/v1/media/public-file?key=${encodeURIComponent(objectKey)}`;
    } catch (e) {
      return url;
    }
  }

  // Handle absolute URLs (localhost/127.0.0.1)
  if (url.startsWith('http://') || url.startsWith('https://')) {
    const urlObj = new URL(url);
    if (urlObj.hostname === 'localhost' || urlObj.hostname === '127.0.0.1') {
      return `${window.location.origin}${urlObj.pathname}${urlObj.search}`;
    }
    return url;
  }

  // Handle relative paths
  const relativePath = url.startsWith('/') ? url : `/${url}`;
  return `${window.location.origin}${relativePath}`;
}
