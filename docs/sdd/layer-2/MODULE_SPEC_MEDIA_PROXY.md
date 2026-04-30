# MODULE SPEC: MEDIA PROXY FALLBACK STRATEGY

> **Authority:** This document is the **Source of Truth** for Media Proxy behavior in VNALO. All statements using MUST, SHALL, and REQUIRED conform to RFC 2119.

> **Module Owner:** media-service (Java/Spring Boot) + frontend/web mediaUtils.ts + frontend/mobile MediaRepository.
> **Status:** TARGET — 2026-04-29

---

## 1. OVERVIEW

The Media Proxy Fallback Strategy defines how VNALO resolves, caches, and delivers media URLs across environments (local, staging, production EC2). The core challenge: Java backends sometimes return URLs with `localhost` or `127.0.0.1` hostnames when running in Docker/containerized environments, which are unreachable from the browser client.

**Key Design Decisions:**
- All media URLs MUST be resolved to a publicly accessible absolute URL before rendering
- Relative URLs MUST be prefixed with the current gateway origin
- Localhost/127.0.0.1 URLs MUST be substituted with the current gateway origin
- S3/CDN URLs MUST be returned as-is (already public)
- Blob URLs (local upload previews) MUST be returned as-is
- Nginx acts as the proxy gateway for media retrieval

---

## 2. SCOPE

### In Scope
- Media URL resolution across all client platforms (Web, Mobile)
- Nginx media proxy routing (`/api/v1/media`, `/api/v1/files`)
- S3 vs local-storage mode handling
- Media URL caching strategy
- Cross-environment URL transformation

### Out of Scope
- Media transcoding or format conversion
- CDN configuration (S3 CloudFront integration is future)
- Media deletion and cleanup (covered in MODULE_SPEC_CHAT §2.4)

---

## 3. STORAGE MODELS

### 3.1 S3 Mode (Production)

```
Java backend uploads file → S3 bucket → returns S3 URL
S3 URL format: https://{bucket}.s3.{region}.amazonaws.com/{path}
S3 URLs are publicly accessible (via bucket policy) OR signed URLs (private)
```

### 3.2 Local Storage Mode (Development)

```
Java backend stores file → local disk (./media-storage)
Returns relative URL: /api/v1/media/storage/{filename}
Nginx proxies /api/v1/media/storage/* to media-service
media-service serves file from local disk
```

---

## 4. URL RESOLUTION ALGORITHM

### 4.1 Client-Side Resolution (MANDATORY — all platforms)

```typescript
function resolveMediaUrl(url: string | null | undefined): string {
  // Rule 1: Null/empty → empty string
  if (!url) return '';

  // Rule 2: Blob URLs (local upload preview) → return as-is
  if (url.startsWith('blob:')) return url;

  // Rule 3: Absolute HTTP/HTTPS URL
  if (url.startsWith('http://') || url.startsWith('https://')) {
    const parsed = new URL(url);

    // Rule 3a: localhost/127.0.0.1 → substitute with current gateway origin
    if (parsed.hostname === 'localhost'
     || parsed.hostname === '127.0.0.1'
     || parsed.hostname === '0.0.0.0') {
      return `${window.location.origin}${parsed.pathname}${parsed.search}`;
    }

    // Rule 3b: Docker internal hostname → substitute
    // Docker internal hostnames include: media-service, core-service, etc.
    if (parsed.hostname.includes('-service')
     || parsed.hostname === 'host.docker.internal') {
      return `${window.location.origin}${parsed.pathname}${parsed.search}`;
    }

    // Rule 3c: S3/CDN/absolute public URL → return as-is
    return url;
  }

  // Rule 4: Relative path → prefix with gateway origin
  const relativePath = url.startsWith('/') ? url : `/${url}`;
  return `${window.location.origin}${relativePath}`;
}
```

### 4.2 Resolution Decision Table

| Input URL | Environment | Output |
|---|---|---|
| `blob:http://localhost:3000/...` | Local dev | Returned as-is (upload preview) |
| `blob:` | Local dev | Returned as-is |
| `http://localhost:8083/api/v1/media/abc.jpg` | EC2 Docker | `https://ec2-public-ip/api/v1/media/abc.jpg` |
| `http://127.0.0.1:8083/api/v1/media/abc.jpg` | EC2 Docker | `https://ec2-public-ip/api/v1/media/abc.jpg` |
| `http://media-service:8083/api/v1/media/abc.jpg` | EC2 Docker | `https://ec2-public-ip/api/v1/media/abc.jpg` |
| `/api/v1/media/storage/abc.jpg` | Any | `https://{gateway}/api/v1/media/storage/abc.jpg` |
| `https://vnalo-media.s3.ap-southeast-1.amazonaws.com/...` | Production | Returned as-is |
| `https://cdn.example.com/assets/avatar.png` | Production | Returned as-is |

---

## 5. NGINX PROXY ROUTING

### 5.1 Media Routing Configuration

```nginx
# Media Service: /api/v1/media
location /api/v1/media {
    # Direct upstream — no variables to avoid DNS-per-request overhead
    proxy_pass http://media-service:8083;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_connect_timeout 5s;
    proxy_read_timeout 30s;
}

# Alias: Upload endpoint
location /api/v1/upload {
    proxy_pass http://media-service:8083/api/v1/media/upload;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_connect_timeout 5s;
    proxy_read_timeout 60s;  # Longer for large file uploads
    client_max_body_size 100M;
}

# Alias: Public file retrieval
location /api/v1/files {
    proxy_pass http://media-service:8083/api/v1/media/public;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_connect_timeout 5s;
    proxy_read_timeout 30s;
}

# Local storage proxy (when media-service is in local-storage mode)
location /api/v1/media/storage {
    proxy_pass http://media-service:8083/api/v1/media/storage;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_connect_timeout 5s;
    proxy_read_timeout 60s;
    proxy_buffering off;  # Stream large files, don't buffer
}
```

### 5.2 Routing Path Verification

| Client Request | Nginx Location | Upstream URI | Backend Receives |
|---|---|---|---|
| `GET /api/v1/media/abc.jpg` | `/api/v1/media` | `http://media-service:8083` | `/api/v1/media/abc.jpg` |
| `POST /api/v1/upload` | `/api/v1/upload` | `http://media-service:8083/api/v1/media/upload` | `/api/v1/media/upload` |
| `GET /api/v1/files/abc.jpg` | `/api/v1/files` | `http://media-service:8083/api/v1/media/public` | `/api/v1/media/public/abc.jpg` |

**Note:** When `proxy_pass` has a URI component (e.g., `/api/v1/media/upload`), Nginx replaces the matched location prefix in the request URI. This is the correct behavior for alias routing.

---

## 6. UPLOAD WORKFLOW

### 6.1 Upload Sequence

```
Client                      Nginx                    media-service:8083
  │                           │                           │
  │  POST /api/v1/upload      │                           │
  │  multipart/form-data       │                           │
  │  Authorization: Bearer <JWT>│                           │
  │──────────────────────────►│                           │
  │                           │  POST /api/v1/media/upload │
  │                           │───────────────────────────►│
  │                           │                           │
  │                           │                           │ Store file
  │                           │                           │ Generate URL
  │                           │                           │ → S3 or local
  │                           │  HTTP 200 { url, ... }   │
  │                           │◄──────────────────────────│
  │  HTTP 200 { data: { url: "..." } }
  │◄───────────────────────────│
  │
  │  Client resolves URL via resolveMediaUrl()
  │  → If localhost/127.0.0.1: substitute window.location.origin
  │  → If S3/CDN: return as-is
  │  → If relative: prefix window.location.origin
  │
  │  <img src={resolvedUrl} />
```

### 6.2 Backend URL Generation Requirements

```
REQUIRED: media-service MUST NOT return URLs with:
  - 'localhost' hostname
  - '127.0.0.1' hostname
  - Docker internal hostnames (e.g., 'media-service')

REQUIRED: media-service MUST return one of:
  - Absolute S3/CDN URL (https://...)
  - Relative URL starting with '/'
  - Path-relative URL (no leading '/')

REQUIRED: When in local-storage mode, media-service MUST return URLs
         relative to its context-path (e.g., '/api/v1/media/storage/{filename}')
```

---

## 7. MEDIA CATEGORY ROUTING

### 7.1 Category-to-Storage Mapping

| Category | Storage Backend | Public URL |
|---|---|---|
| `CHAT_IMAGE` | S3 or local | `/api/v1/media/{id}` |
| `CHAT_VIDEO` | S3 or local | `/api/v1/media/{id}` |
| `CHAT_FILE` | S3 or local | `/api/v1/files/{id}` |
| `CHAT_VOICE` | S3 or local | `/api/v1/media/{id}` |
| `AVATAR` | S3 or local | `/api/v1/media/{id}` |
| `COVER` | S3 or local | `/api/v1/media/{id}` |
| `STICKER` | S3 (preferred) | Public CDN or `/api/v1/media/{id}` |
| `EMOJI` | S3 (preferred) | Public CDN or `/api/v1/media/{id}` |
| `STORY` | S3 | Public URL |
| `TIMELINE` | S3 | Public URL |

---

## 8. FALLBACK STRATEGY

### 8.1 Client-Side Fallback Chain

```
Attempt 1: Load image from resolved URL
    ↓
If 404 Not Found:
    Attempt 2: Check if URL contains localhost/127.0.0.1
                → Re-resolve with window.location.origin
    ↓
If still fails:
    Attempt 3: Show placeholder image
                → Log error with resolved URL and original URL
```

### 8.2 Nginx Fallback (Local Storage Mode)

```
When media-service is in local-storage mode:
  1. Nginx serves /api/v1/media/storage/* directly via proxy_pass
  2. If media-service is down:
     → Nginx returns 502 Bad Gateway
     → Client retry logic applies (up to 3 retries)
```

### 8.3 CDN Fallback

```
When S3 is the primary storage:
  1. Primary: Serve from S3 CloudFront CDN (if configured)
  2. Fallback: Serve from S3 bucket directly
  3. Emergency: Serve from media-service local cache (if cached)

Headers:
  Cache-Control: public, max-age=31536000 (for immutable assets)
  Cache-Control: public, max-age=86400 (for user-generated content)
```

---

## 9. CACHING STRATEGY

### 9.1 Browser Cache

| Asset Type | Cache-Control | Strategy |
|---|---|---|
| User avatar | `public, max-age=86400` | ETag-based revalidation |
| Chat images | `public, max-age=31536000` | Immutable (content-addressed URL) |
| Chat videos | `public, max-age=86400` | Cache with range request support |
| Stickers | `public, max-age=31536000` | Immutable |
| User-generated uploads | `public, max-age=0, must-revalidate` | No immutable URL, revalidate each visit |

### 9.2 Nginx Cache

```
proxy_cache_path /var/cache/nginx/media levels=1:2 keys_zone=media_cache:10m max_size=1g;

location /api/v1/media {
    proxy_cache media_cache;
    proxy_cache_valid 200 24h;
    proxy_cache_key "$host$uri";
    add_header X-Cache-Status $upstream_cache_status;
}
```

---

## 10. SECURITY RULES

### SR-1: Upload Authentication

```
REQUIRED: All media upload requests MUST include valid JWT Bearer token.
media-service MUST validate JWT before accepting uploads.
Anonymous uploads are PROHIBITED.
```

### SR-2: File Type Validation

```
REQUIRED: media-service MUST validate MIME type on upload using magic byte detection.
Client-reported Content-Type is UNTRUSTED.
Allowed types per category:
  - CHAT_IMAGE: image/jpeg, image/png, image/gif, image/webp, image/heic
  - CHAT_VIDEO: video/mp4, video/webm, video/quicktime, video/x-m4v
  - CHAT_FILE: application/pdf, application/msword, etc.
```

### SR-3: File Size Limits

```
REQUIRED: media-service MUST enforce per-category size limits:
  - CHAT_IMAGE: 20 MB
  - CHAT_VIDEO: 100 MB
  - CHAT_FILE: 100 MB
  - AVATAR: 5 MB
Exceeded limits: HTTP 413 Payload Too Large
```

### SR-4: URL Access Control

```
REQUIRED: Private media (CHAT_IMAGE, CHAT_VIDEO, CHAT_FILE) MUST require authentication.
media-service MUST verify JWT on GET /api/v1/media/{id} requests.
Public media (STICKER, EMOJI, STORY, TIMELINE) MAY be accessible without auth.
Avatar images for profile display: served via authenticated request.
```

---

## 11. EVIDENCE

| Component | File |
|---|---|
| Media URL resolver (Web) | `frontend/web/src/utils/mediaUtils.ts` |
| Media API client (Web) | `frontend/web/src/api.client.ts` |
| Chat upload (Web) | `frontend/web/src/features/chat/chat.api.ts` |
| Avatar upload (Web) | `frontend/web/src/features/profile/avatar.service.ts` |
| Media controller (Java) | `backend/java-services/services/media-service/src/.../controller/` |
| Media service (Java) | `backend/java-services/services/media-service/src/.../service/` |
| Nginx routing | `nginx.conf` |

---

## 12. REMEDIATION CHECKLIST

| Item | Priority | Status |
|---|---|---|
| Implement magic byte validation for uploaded files | CRITICAL | `[SPEC_ONLY]` |
| Enforce JWT validation on all media GET endpoints | CRITICAL | `[SPEC_ONLY]` |
| Implement per-category size limits | HIGH | `[SPEC_ONLY]` |
| Add Cache-Control headers for immutable assets | HIGH | `[SPEC_ONLY]` |
| Configure Nginx proxy cache for media | MEDIUM | `[SPEC_ONLY]` |
| Add CDN (CloudFront) integration for production | MEDIUM | Planned |
| Implement signed URL generation for private media | MEDIUM | Planned |
| Add WebP/AVIF auto-conversion for images | LOW | Planned |
