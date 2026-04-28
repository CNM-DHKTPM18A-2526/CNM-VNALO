import { WS_BASE_URL } from '../api.client';

export function resolveMediaUrl(url?: string | null): string {
  if (!url) return '';

  if (url.startsWith('blob:')) {
    return url;
  }

  // Handle absolute URLs
  if (url.startsWith('http://') || url.startsWith('https://')) {
    const urlObj = new URL(url);
    
    // If the URL points to localhost/127.0.0.1 (common in Java backend response on EC2), 
    // we must redirect it to the current public gateway.
    if (urlObj.hostname === 'localhost' || urlObj.hostname === '127.0.0.1') {
      return `${window.location.origin}${urlObj.pathname}${urlObj.search}`;
    }
    return url;
  }

  // Handle relative paths
  const relativePath = url.startsWith('/') ? url : `/${url}`;
  return `${window.location.origin}${relativePath}`;
}
