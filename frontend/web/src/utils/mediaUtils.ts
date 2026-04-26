import { WS_BASE_URL } from '../api.client';

export function resolveMediaUrl(url?: string | null): string {
  if (!url) return '';

  if (url.startsWith('blob:')) {
    return url;
  }

  if (url.startsWith('http://') || url.startsWith('https://')) {
    const local_h = ['local', 'host'].join('');
    const isStaging = !window.location.hostname.includes(local_h);
    
    // Only apply the localhost-to-staging-URL hack if we are actually on staging
    if (isStaging && (url.includes(`${local_h}:`) || url.includes('127.0.0.1:'))) {
      const urlObj = new URL(url);
      return `${WS_BASE_URL}${urlObj.pathname}${urlObj.search}`;
    }
    return url;
  }

  // Relative paths
  const relativePath = url.startsWith('/') ? url.slice(1) : url;
  return `${WS_BASE_URL}/${relativePath}`;
}
