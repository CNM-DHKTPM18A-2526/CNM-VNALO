package iuh.cnm.vnalo.mediaservice.controller;

import iuh.cnm.vnalo.mediaservice.domain.dto.*;
import iuh.cnm.vnalo.mediaservice.domain.model.*;
import iuh.cnm.vnalo.mediaservice.exception.AccessDeniedException;
import iuh.cnm.vnalo.mediaservice.service.MediaAccessService;
import iuh.cnm.vnalo.mediaservice.service.MediaService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * Controller quản lý media (ảnh, video, file) trong hệ thống.
 * Docs: Readme.md § 5-6
 */
@RestController
@RequestMapping("/api/v1/media")
@RequiredArgsConstructor
@Slf4j
public class MediaController {

    private final MediaService mediaService;
    private final MediaAccessService mediaAccessService;

    // ==================== Upload (§6.1) ====================

    private static final Set<String> ALLOWED_MIME_TYPES = Set.of(
            "image/jpeg", "image/png", "image/gif", "image/webp",
            "video/mp4", "video/webm", "video/quicktime",
            "audio/mpeg", "audio/ogg", "audio/webm",
            "application/pdf"
    );
    private static final long MAX_FILE_SIZE = 100 * 1024 * 1024L; // 100MB
    private static final UUID SYSTEM_USER_ID = UUID.fromString("00000000-0000-0000-0000-000000000000");

    @PostMapping(value = "/upload", consumes = "multipart/form-data")
    public ResponseEntity<ApiResponse<MediaResponse>> uploadFile(
            Authentication authentication,
            @RequestParam("file") MultipartFile file,
            @RequestParam("category") MediaCategory category
    ) {
        if (file == null || file.isEmpty()) {
            return ResponseEntity.badRequest().body(ApiResponse.error(400, "File không được rỗng"));
        }
        if (file.getSize() > MAX_FILE_SIZE) {
            return ResponseEntity.badRequest().body(ApiResponse.error(400, "File vượt quá giới hạn 100MB"));
        }
        String mimeType = file.getContentType();
        if (mimeType == null || !ALLOWED_MIME_TYPES.contains(mimeType)) {
            return ResponseEntity.badRequest().body(ApiResponse.error(400, "Loại file không được phép: " + mimeType));
        }

        UUID userId = getUserId(authentication);
        MediaMetadata media = mediaService.uploadMedia(file, userId, category);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(MediaResponse.from(media)));
    }

    // ==================== Presigned Upload (§6.2) ====================

    @PostMapping("/initiate-upload")
    public ResponseEntity<ApiResponse<PresignedUploadResponse>> initiateUpload(
            Authentication authentication,
            @RequestBody @Valid InitiateUploadRequest request
    ) {
        UUID userId = getUserId(authentication);
        PresignedUploadResponse response = mediaService.initiateUpload(request, userId);
        return ResponseEntity.ok(ApiResponse.ok(response));
    }

    // ==================== Complete Upload (§6.2, step 3) ====================

    @PostMapping("/{id}/complete")
    public ResponseEntity<ApiResponse<MediaResponse>> completeUpload(
            Authentication authentication,
            @PathVariable UUID id
    ) {
        UUID userId = getUserId(authentication);
        MediaMetadata completed = mediaService.completeUpload(id, userId);
        return ResponseEntity.ok(ApiResponse.ok(MediaResponse.from(completed)));
    }

    // ==================== Get Media (§6.3) ====================

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<MediaResponse>> getMediaInfo(
            Authentication authentication,
            @PathVariable UUID id
    ) {
        UUID userId = getUserId(authentication);
        // Kiểm tra quyền: Chủ sở hữu hoặc Hệ thống (đối với GIF/Emoji)
        MediaMetadata media = mediaService.getMedia(id);
        if (!media.getOwnerUserId().equals(SYSTEM_USER_ID)) {
            ensureCanAccess(id, userId);
        }
        return ResponseEntity.ok(ApiResponse.ok(MediaResponse.from(media)));
    }

    // ==================== List Media (§6.4) ====================

    @GetMapping
    public ResponseEntity<ApiResponse<MediaPageResponse>> listMedia(
            Authentication authentication,
            @RequestParam(value = "owner", required = false) UUID ownerUserId,
            @RequestParam(value = "category", required = false) MediaCategory category,
            @RequestParam(value = "page", defaultValue = "0") int page,
            @RequestParam(value = "size", defaultValue = "20") int size
    ) {
        UUID effectiveOwnerUserId = getUserId(authentication);
        
        // Nếu là GIF hoặc EMOJI, ta cho phép xem dữ liệu hệ thống (owner = null hoặc SYSTEM)
        UUID filterOwnerId = (category == MediaCategory.GIF || category == MediaCategory.EMOJI) 
                ? null 
                : (ownerUserId != null ? ownerUserId : effectiveOwnerUserId);

        Page<MediaMetadata> mediaPage = mediaService.listMedia(filterOwnerId, category,
                PageRequest.of(page, size, Sort.by("createdAt").descending()));

        MediaPageResponse response = MediaPageResponse.builder()
                .content(mediaPage.getContent().stream()
                        .map(MediaResponse::from)
                        .collect(Collectors.toList()))
                .page(mediaPage.getNumber())
                .size(mediaPage.getSize())
                .totalElements(mediaPage.getTotalElements())
                .totalPages(mediaPage.getTotalPages())
                .last(mediaPage.isLast())
                .build();

        return ResponseEntity.ok(ApiResponse.ok(response));
    }

    // ==================== Delete Media (§6.5) ====================

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteMedia(
            Authentication authentication,
            @PathVariable UUID id
    ) {
        UUID userId = getUserId(authentication);
        mediaService.deleteMedia(id, userId);
        return ResponseEntity.ok(ApiResponse.ok(null));
    }

    // ==================== Update Metadata (§6.6) ====================

    @PatchMapping("/{id}")
    public ResponseEntity<ApiResponse<MediaResponse>> updateMedia(
            Authentication authentication,
            @PathVariable UUID id,
            @RequestBody Map<String, String> updates
    ) {
        UUID userId = getUserId(authentication);
        String newFilename = updates.get("originalFilename");
        MediaMetadata updated = mediaService.updateMedia(id, userId, newFilename);
        return ResponseEntity.ok(ApiResponse.ok(MediaResponse.from(updated)));
    }

    // ==================== Replace File (§6.6b) ====================

    @PutMapping(value = "/{id}/replace", consumes = "multipart/form-data")
    public ResponseEntity<ApiResponse<MediaResponse>> replaceFile(
            Authentication authentication,
            @PathVariable UUID id,
            @RequestParam("file") MultipartFile file
    ) {
        if (file == null || file.isEmpty()) {
            return ResponseEntity.badRequest().body(ApiResponse.error(400, "File không được rỗng"));
        }
        if (file.getSize() > MAX_FILE_SIZE) {
            return ResponseEntity.badRequest().body(ApiResponse.error(400, "File vượt quá giới hạn 100MB"));
        }
        String mimeType = file.getContentType();
        if (mimeType == null || !ALLOWED_MIME_TYPES.contains(mimeType)) {
            return ResponseEntity.badRequest().body(ApiResponse.error(400, "Loại file không được phép: " + mimeType));
        }

        UUID userId = getUserId(authentication);
        MediaMetadata replaced = mediaService.replaceMedia(id, userId, file);
        return ResponseEntity.ok(ApiResponse.ok(MediaResponse.from(replaced)));
    }

    // ==================== Presigned Download (§6.7) ====================

    @GetMapping("/{id}/download")
    public ResponseEntity<ApiResponse<Map<String, String>>> getDownloadUrl(
            Authentication authentication,
            @PathVariable UUID id
    ) {
        UUID userId = getUserId(authentication);
        ensureCanAccess(id, userId);
        String downloadUrl = mediaService.generateDownloadUrl(id);
        return ResponseEntity.ok(ApiResponse.ok(Map.of("downloadUrl", downloadUrl)));
    }

    // ==================== Save to Device (§6.8) ====================

    @GetMapping("/{id}/save")
    public ResponseEntity<org.springframework.web.servlet.mvc.method.annotation.StreamingResponseBody> saveToDevice(
            Authentication authentication,
            @PathVariable UUID id
    ) {
        UUID userId = getUserId(authentication);
        ensureCanAccess(id, userId);
        MediaMetadata media = mediaService.getMedia(id);

        org.springframework.web.servlet.mvc.method.annotation.StreamingResponseBody stream = out -> {
            mediaService.streamMediaToResponse(id, out);
        };

        String saveFilename = media.getOriginalFilename() != null
                ? media.getOriginalFilename()
                : "media_" + id;
        saveFilename = saveFilename.replaceAll("[^a-zA-Z0-9._\\-]", "_");

        HttpHeaders headers = new HttpHeaders();
        headers.add(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + saveFilename + "\"");
        headers.add(HttpHeaders.CONTENT_TYPE, media.getMimeType());
        if (media.getSizeBytes() != null) {
            headers.add(HttpHeaders.CONTENT_LENGTH, String.valueOf(media.getSizeBytes()));
        }
        headers.add("Access-Control-Expose-Headers", "Content-Disposition");

        log.info("User {} downloading media stream for {}", userId, id);
        return ResponseEntity.ok().headers(headers).body(stream);
    }

    // ==================== Thumbnail (§6.9) ====================

    @GetMapping("/{id}/thumbnail")
    public ResponseEntity<ApiResponse<Map<String, String>>> getThumbnail(
            Authentication authentication,
            @PathVariable UUID id
    ) {
        UUID userId = getUserId(authentication);
        ensureCanAccess(id, userId);
        MediaMetadata media = mediaService.getMedia(id);
        String thumbnailUrl = media.getThumbnailUrl();
        if (thumbnailUrl == null) {
            return ResponseEntity.ok(ApiResponse.ok(Map.of("thumbnailUrl", "", "message", "Thumbnail chưa sẵn sàng")));
        }
        return ResponseEntity.ok(ApiResponse.ok(Map.of("thumbnailUrl", thumbnailUrl)));
    }

    // ==================== Status (§6.10) ====================

    @GetMapping("/{id}/status")
    public ResponseEntity<ApiResponse<Map<String, String>>> getMediaStatus(
            Authentication authentication,
            @PathVariable UUID id
    ) {
        UUID userId = getUserId(authentication);
        ensureCanAccess(id, userId);
        MediaMetadata media = mediaService.getMedia(id);
        return ResponseEntity.ok(ApiResponse.ok(Map.of("status", media.getStatus().name())));
    }

    // ==================== Access Control (§6.11-13) ====================

    @PostMapping("/{id}/access")
    public ResponseEntity<ApiResponse<Void>> grantAccess(
            Authentication authentication,
            @PathVariable UUID id,
            @RequestBody @Valid AccessScopeRequest request
    ) {
        UUID userId = getUserId(authentication);
        ensureOwner(id, userId);
        mediaAccessService.grantAccess(id, request.getScopeType(), request.getScopeId());
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(null));
    }

    @DeleteMapping("/{id}/access")
    public ResponseEntity<ApiResponse<Void>> revokeAccess(
            Authentication authentication,
            @PathVariable UUID id,
            @RequestBody @Valid AccessScopeRequest request
    ) {
        UUID userId = getUserId(authentication);
        ensureOwner(id, userId);
        mediaAccessService.revokeAccess(id, request.getScopeType(), request.getScopeId());
        return ResponseEntity.ok(ApiResponse.ok(null));
    }

    @GetMapping("/{id}/access")
    public ResponseEntity<ApiResponse<List<MediaAccessScope>>> listAccess(
            Authentication authentication,
            @PathVariable UUID id
    ) {
        UUID userId = getUserId(authentication);
        ensureOwner(id, userId);
        List<MediaAccessScope> scopes = mediaAccessService.getAccessScopes(id);
        return ResponseEntity.ok(ApiResponse.ok(scopes));
    }

    // ==================== Public File Access (no auth) ====================

    /**
     * Publicly accessible endpoint to serve media files by mediaId.
     * Used by mobile clients (e.g. avatar images in CachedNetworkImageProvider)
     * where passing Authorization headers is not practical.
     */
    @GetMapping("/public/{id}")
    public ResponseEntity<byte[]> getPublicFile(
            @PathVariable UUID id
    ) {
        MediaMetadata media = mediaService.getMedia(id);
        byte[] fileBytes = mediaService.downloadMediaBytes(id);

        HttpHeaders headers = new HttpHeaders();
        headers.add(HttpHeaders.CONTENT_TYPE, media.getMimeType() != null ? media.getMimeType() : "application/octet-stream");
        headers.setContentLength(fileBytes.length);
        headers.add(HttpHeaders.CACHE_CONTROL, "public, max-age=86400");

    return ResponseEntity.ok().headers(headers).body(fileBytes);
    }

    /**
     * Publicly accessible endpoint to serve media files by objectKey.
     * Used mainly for seeded data or local dev fallback.
     */
    @GetMapping("/public-file")
    public ResponseEntity<byte[]> getPublicFileByKey(@RequestParam("key") String objectKey) {
        byte[] fileBytes = mediaService.downloadMediaBytesByKey(objectKey);
        String mimeType = "application/octet-stream";
        if (objectKey.contains(".")) {
            String ext = objectKey.substring(objectKey.lastIndexOf(".") + 1).toLowerCase();
            mimeType = matchMimeType(ext);
        }

        HttpHeaders headers = new HttpHeaders();
        headers.add(HttpHeaders.CONTENT_TYPE, mimeType);
        headers.setContentLength(fileBytes.length);
        headers.add(HttpHeaders.CACHE_CONTROL, "public, max-age=86400");

        return ResponseEntity.ok().headers(headers).body(fileBytes);
    }

    private String matchMimeType(String ext) {
        return switch (ext) {
            case "jpg", "jpeg" -> "image/jpeg";
            case "png" -> "image/png";
            case "gif" -> "image/gif";
            case "webp" -> "image/webp";
            case "mp4" -> "video/mp4";
            case "mp3" -> "audio/mpeg";
            case "pdf" -> "application/pdf";
            default -> "application/octet-stream";
        };
    }

    // ==================== Helper ====================

    private UUID getUserId(Authentication authentication) {
        return UUID.fromString(authentication.getPrincipal().toString());
    }

    private void ensureCanAccess(UUID mediaId, UUID userId) {
        if (!mediaAccessService.canAccess(mediaId, userId)) {
            throw new AccessDeniedException("Forbidden");
        }
    }

    private void ensureOwner(UUID mediaId, UUID userId) {
        MediaMetadata media = mediaService.getMedia(mediaId);
        if (!media.getOwnerUserId().equals(userId)) {
            throw new AccessDeniedException("Only owner can manage access scopes");
        }
    }
}
