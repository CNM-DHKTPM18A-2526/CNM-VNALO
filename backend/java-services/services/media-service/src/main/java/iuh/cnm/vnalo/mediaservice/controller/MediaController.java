package iuh.cnm.vnalo.mediaservice.controller;

import iuh.cnm.vnalo.mediaservice.domain.dto.ApiResponse;
import iuh.cnm.vnalo.mediaservice.domain.dto.MediaPageResponse;
import iuh.cnm.vnalo.mediaservice.domain.dto.MediaResponse;
import iuh.cnm.vnalo.mediaservice.domain.dto.PresignedUploadResponse;
import iuh.cnm.vnalo.mediaservice.domain.model.MediaAccessScope;
import iuh.cnm.vnalo.mediaservice.domain.model.MediaCategory;
import iuh.cnm.vnalo.mediaservice.domain.model.MediaObject;
import iuh.cnm.vnalo.mediaservice.domain.model.ScopeType;
import iuh.cnm.vnalo.mediaservice.exception.AccessDeniedException;
import iuh.cnm.vnalo.mediaservice.service.MediaAccessService;
import iuh.cnm.vnalo.mediaservice.service.MediaService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.UUID;

/**
 * Controller quản lý media (ảnh, video, file) trong hệ thống.
 *
 * Chức năng chính:
 * - Upload file trực tiếp hoặc qua presigned URL
 * - Lấy thông tin media theo ID (có kiểm tra quyền truy cập)
 * - Quản lý quyền truy cập media (cấp, thu hồi, xem)
 *
 * Tất cả API đều yêu cầu JWT token trong header: Authorization: Bearer <token>
 * userId được lấy tự động từ JWT token, không cần truyền thủ công.
 */
@RestController
@RequestMapping("/api/v1/media")
@RequiredArgsConstructor
@Slf4j
public class MediaController {

    private final MediaService mediaService;
    private final MediaAccessService mediaAccessService;

    // ==================== Upload ====================

    /**
     * Upload file trực tiếp lên server → server tải lên S3.
     * Dùng khi client gửi file nhỏ (ảnh chat, avatar, story...).
     *
     * Đầu vào (form-data):
     * - file     (File, bắt buộc)  : File cần upload (ảnh, video, tài liệu...), tối đa 100MB
     * - category (Text, bắt buộc)  : Loại media, một trong các giá trị:
     *     AVATAR     - Ảnh đại diện
     *     COVER      - Ảnh bìa
     *     CHAT_IMAGE - Ảnh gửi trong chat
     *     CHAT_VIDEO - Video gửi trong chat
     *     CHAT_FILE  - File đính kèm trong chat
     *     CHAT_VOICE - Tin nhắn thoại
     *     STORY      - Ảnh/video story
     *     TIMELINE   - Ảnh đăng trên timeline
     *
     * Đầu ra (201 Created): MediaResponse chứa url, mimeType, sizeBytes, status...
     */
    @PostMapping(value = "/upload", consumes = "multipart/form-data")
    public ResponseEntity<ApiResponse<MediaResponse>> uploadFile(
            Authentication authentication,
            @RequestParam("file") MultipartFile file,
            @RequestParam("category") MediaCategory category
    ) {
        UUID userId = getUserId(authentication);
        MediaObject mediaObject = mediaService.uploadMedia(file, userId, category);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(MediaResponse.from(mediaObject)));
    }

    /**
     * Tạo presigned URL để client upload file trực tiếp lên S3 (không qua server).
     * Dùng cho file lớn (video, file nặng) để giảm tải cho server.
     *
     * Luồng hoạt động:
     * 1. Client gọi API này → nhận presignedUrl
     * 2. Client dùng presignedUrl để PUT file trực tiếp lên S3
     * 3. File được lưu trên S3, metadata được lưu trong database
     *
     * Đầu vào (request params):
     * - filename    (String, bắt buộc) : Tên file gốc, ví dụ: "video.mp4"
     * - contentType (String, bắt buộc) : MIME type của file, ví dụ: "video/mp4", "image/jpeg"
     * - size        (long, bắt buộc)   : Kích thước file tính bằng bytes
     * - category    (String, bắt buộc) : Loại media (giống API upload ở trên)
     *
     * Đầu ra (200 OK): PresignedUploadResponse chứa:
     * - mediaId      : ID của media trong database
     * - objectKey    : Key lưu trên S3
     * - presignedUrl : URL để client PUT file lên S3 (hết hạn sau 10 phút)
     * - publicUrl    : URL công khai để truy cập file sau khi upload xong
     */
    @PostMapping("/initiate-upload")
    public ResponseEntity<ApiResponse<PresignedUploadResponse>> initiateUpload(
            Authentication authentication,
            @RequestParam("filename") String filename,
            @RequestParam("contentType") String contentType,
            @RequestParam("size") long size,
            @RequestParam("category") MediaCategory category
    ) {
        UUID userId = getUserId(authentication);
        PresignedUploadResponse response = mediaService.initiateUpload(filename, contentType, size, userId, category);
        return ResponseEntity.ok(ApiResponse.ok(response));
    }

    // ==================== Truy vấn ====================

    /**
     * Lấy thông tin chi tiết của một media theo ID.
     * Có kiểm tra quyền truy cập: chỉ owner hoặc user được cấp quyền mới xem được.
     *
     * Đầu vào:
     * - id (UUID, bắt buộc, trên URL) : ID của media cần lấy thông tin
     *
     * Đầu ra (200 OK): MediaResponse chứa url, thumbnailUrl, mimeType, sizeBytes, status...
     *
     * Lỗi có thể xảy ra:
     * - 403 Forbidden  : Không có quyền truy cập media này
     * - 404 Not Found  : Không tìm thấy media với ID này
     */
    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<MediaResponse>> getMediaInfo(
            Authentication authentication,
            @PathVariable UUID id
    ) {
        UUID userId = getUserId(authentication);

        // Kiểm tra quyền truy cập: owner hoặc user được cấp quyền
        if (!mediaAccessService.canAccess(id, userId)) {
            throw new AccessDeniedException("Bạn không có quyền truy cập media này");
        }

        MediaObject media = mediaService.getMedia(id);
        return ResponseEntity.ok(ApiResponse.ok(MediaResponse.from(media)));
    }

    // ==================== Quản lý quyền truy cập ====================

    /**
     * Cấp quyền truy cập media cho user hoặc nhóm hội thoại.
     * Chỉ chủ sở hữu (owner) media mới được phép cấp quyền.
     *
     * Đầu vào:
     * - mediaId   (UUID, bắt buộc, trên URL)        : ID của media cần cấp quyền
     * - scopeType (String, bắt buộc, request param)  : Loại quyền, một trong:
     *     PUBLIC       - Công khai, ai cũng xem được
     *     USER         - Cấp quyền cho 1 user cụ thể
     *     CONVERSATION - Cấp quyền cho thành viên hội thoại
     * - scopeId   (UUID, bắt buộc, request param)    : ID đối tượng được cấp quyền:
     *     Nếu scopeType = USER         → scopeId = userId của người được cấp
     *     Nếu scopeType = CONVERSATION → scopeId = conversationId
     *     Nếu scopeType = PUBLIC       → scopeId = bất kỳ UUID nào (thường dùng mediaId)
     *
     * Đầu ra (201 Created): MediaAccessScope chứa mediaId, scopeType, scopeId, createdAt
     *
     * Lỗi: 403 nếu không phải owner
     */
    @PostMapping("/{mediaId}/access")
    public ResponseEntity<ApiResponse<MediaAccessScope>> grantAccess(
            Authentication authentication,
            @PathVariable UUID mediaId,
            @RequestParam("scopeType") ScopeType scopeType,
            @RequestParam("scopeId") UUID scopeId
    ) {
        UUID userId = getUserId(authentication);

        // Chỉ chủ sở hữu mới được cấp quyền
        MediaObject media = mediaService.getMedia(mediaId);
        if (!media.getOwnerUserId().equals(userId)) {
            throw new AccessDeniedException("Chỉ chủ sở hữu media mới được cấp quyền truy cập");
        }

        MediaAccessScope scope = mediaAccessService.grantAccess(mediaId, scopeType, scopeId);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(scope));
    }

    /**
     * Thu hồi quyền truy cập media.
     * Chỉ chủ sở hữu (owner) media mới được phép thu hồi.
     *
     * Đầu vào:
     * - mediaId   (UUID, bắt buộc, trên URL)        : ID của media cần thu hồi quyền
     * - scopeType (String, bắt buộc, request param)  : Loại quyền cần thu hồi (PUBLIC/USER/CONVERSATION)
     * - scopeId   (UUID, bắt buộc, request param)    : ID đối tượng bị thu hồi quyền
     *
     * Đầu ra (200 OK): ApiResponse với data = null
     *
     * Lỗi: 403 nếu không phải owner
     */
    @DeleteMapping("/{mediaId}/access")
    public ResponseEntity<ApiResponse<Void>> revokeAccess(
            Authentication authentication,
            @PathVariable UUID mediaId,
            @RequestParam("scopeType") ScopeType scopeType,
            @RequestParam("scopeId") UUID scopeId
    ) {
        UUID userId = getUserId(authentication);

        // Chỉ chủ sở hữu mới được thu hồi quyền
        MediaObject media = mediaService.getMedia(mediaId);
        if (!media.getOwnerUserId().equals(userId)) {
            throw new AccessDeniedException("Chỉ chủ sở hữu media mới được thu hồi quyền truy cập");
        }

        mediaAccessService.revokeAccess(mediaId, scopeType, scopeId);
        return ResponseEntity.ok(ApiResponse.ok(null));
    }

    /**
     * Xem danh sách tất cả quyền truy cập của một media.
     * Chỉ chủ sở hữu (owner) media mới được phép xem.
     *
     * Đầu vào:
     * - mediaId (UUID, bắt buộc, trên URL) : ID của media cần xem quyền
     *
     * Đầu ra (200 OK): Danh sách MediaAccessScope, mỗi phần tử chứa:
     * - mediaId   : ID media
     * - scopeType : Loại quyền (PUBLIC/USER/CONVERSATION)
     * - scopeId   : ID đối tượng được cấp quyền
     * - createdAt : Thời điểm cấp quyền
     *
     * Lỗi: 403 nếu không phải owner
     */
    @GetMapping("/{mediaId}/access")
    public ResponseEntity<ApiResponse<List<MediaAccessScope>>> getAccessScopes(
            Authentication authentication,
            @PathVariable UUID mediaId
    ) {
        UUID userId = getUserId(authentication);

        // Chỉ chủ sở hữu mới được xem danh sách quyền
        MediaObject media = mediaService.getMedia(mediaId);
        if (!media.getOwnerUserId().equals(userId)) {
            throw new AccessDeniedException("Chỉ chủ sở hữu media mới được xem danh sách quyền truy cập");
        }

        return ResponseEntity.ok(ApiResponse.ok(mediaAccessService.getAccessScopes(mediaId)));
    }

    // ==================== Delete ====================

    /**
     * Xóa media (xóa file trên S3 + xóa record trong DB + xóa access scopes).
     * Chỉ chủ sở hữu (owner) mới được xóa.
     *
     * Đầu vào:
     * - id (UUID, trên URL) : ID của media cần xóa
     *
     * Đầu ra (200 OK): ApiResponse xác nhận đã xóa
     * Lỗi: 403 nếu không phải owner, 404 nếu không tìm thấy
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteMedia(
            Authentication authentication,
            @PathVariable UUID id
    ) {
        UUID userId = getUserId(authentication);
        mediaService.deleteMedia(id, userId);
        return ResponseEntity.ok(ApiResponse.ok(null));
    }

    // ==================== List (flexible filter + pagination) ====================

    /**
     * Lấy danh sách media có hỗ trợ filter riêng lẻ hoặc kết hợp + phân trang.
     *
     * Query params (tất cả optional):
     * - owner          (UUID)   : Filter theo chủ sở hữu
     * - conversationId (UUID)   : Filter theo conversation
     * - category       (String) : Filter theo loại media (CHAT_IMAGE, AVATAR, CHAT_VIDEO...)
     * - page           (int)    : Trang (bắt đầu từ 0), mặc định 0
     * - size           (int)    : Số lượng mỗi trang, mặc định 20
     *
     * Ví dụ:
     * - GET /api/v1/media?owner=xxx                         → Tất cả media của owner
     * - GET /api/v1/media?category=CHAT_IMAGE               → Tất cả ảnh chat
     * - GET /api/v1/media?owner=xxx&category=AVATAR         → Avatar của owner
     * - GET /api/v1/media?conversationId=yyy                → Media trong conversation
     * - GET /api/v1/media?conversationId=yyy&category=CHAT_VIDEO → Video trong conversation
     * - GET /api/v1/media?page=1&size=10                    → Trang 2, 10 items
     */
    @GetMapping
    public ResponseEntity<ApiResponse<MediaPageResponse>> listMedia(
            Authentication authentication,
            @RequestParam(value = "owner", required = false) UUID ownerUserId,
            @RequestParam(value = "conversationId", required = false) UUID conversationId,
            @RequestParam(value = "category", required = false) MediaCategory category,
            @RequestParam(value = "page", defaultValue = "0") int page,
            @RequestParam(value = "size", defaultValue = "20") int size
    ) {
        org.springframework.data.domain.Page<MediaObject> mediaPage =
                mediaService.listMedia(ownerUserId, conversationId, category,
                        org.springframework.data.domain.PageRequest.of(page, size,
                                org.springframework.data.domain.Sort.by("createdAt").descending()));

        MediaPageResponse response = MediaPageResponse.builder()
                .content(mediaPage.getContent().stream()
                        .map(MediaResponse::from)
                        .collect(java.util.stream.Collectors.toList()))
                .page(mediaPage.getNumber())
                .size(mediaPage.getSize())
                .totalElements(mediaPage.getTotalElements())
                .totalPages(mediaPage.getTotalPages())
                .last(mediaPage.isLast())
                .build();

        return ResponseEntity.ok(ApiResponse.ok(response));
    }

    // ==================== Update Metadata ====================

    /**
     * Cập nhật metadata của media (filename, category).
     * Chỉ chủ sở hữu mới được cập nhật.
     *
     * Đầu vào (request params):
     * - id       (UUID, trên URL)              : ID media
     * - filename (String, optional)             : Tên file mới
     * - category (MediaCategory, optional)      : Category mới
     *
     * Đầu ra (200 OK): MediaResponse đã cập nhật
     */
    @PatchMapping("/{id}")
    public ResponseEntity<ApiResponse<MediaResponse>> updateMetadata(
            Authentication authentication,
            @PathVariable UUID id,
            @RequestParam(value = "filename", required = false) String filename,
            @RequestParam(value = "category", required = false) MediaCategory category
    ) {
        UUID userId = getUserId(authentication);
        MediaObject updated = mediaService.updateMetadata(id, userId, filename, category);
        return ResponseEntity.ok(ApiResponse.ok(MediaResponse.from(updated)));
    }

    // ==================== Complete Upload ====================

    /**
     * Xác nhận upload hoàn tất (dùng sau presigned upload).
     * Chuyển status từ PRE_UPLOAD → READY.
     *
     * Đầu vào:
     * - id (UUID, trên URL) : ID media cần xác nhận
     *
     * Đầu ra (200 OK): MediaResponse với status = READY
     * Lỗi: 400 nếu media không ở trạng thái PRE_UPLOAD
     */
    @PostMapping("/{id}/complete")
    public ResponseEntity<ApiResponse<MediaResponse>> completeUpload(
            Authentication authentication,
            @PathVariable UUID id
    ) {
        UUID userId = getUserId(authentication);
        MediaObject completed = mediaService.completeUpload(id, userId);
        return ResponseEntity.ok(ApiResponse.ok(MediaResponse.from(completed)));
    }

    // ==================== Download (Presigned URL) ====================

    /**
     * Tạo presigned download URL (hết hạn sau 60 phút).
     * Dùng khi client cần URL trực tiếp đến S3 (stream trong trình phát media...).
     *
     * Đầu vào:
     * - id (UUID, trên URL) : ID media cần tải
     *
     * Đầu ra (200 OK): JSON chứa downloadUrl
     */
    @GetMapping("/{id}/download")
    public ResponseEntity<ApiResponse<java.util.Map<String, String>>> getDownloadUrl(
            Authentication authentication,
            @PathVariable UUID id
    ) {
        UUID userId = getUserId(authentication);

        if (!mediaAccessService.canAccess(id, userId)) {
            throw new AccessDeniedException("Bạn không có quyền tải media này");
        }

        String downloadUrl = mediaService.generateDownloadUrl(id);
        return ResponseEntity.ok(ApiResponse.ok(java.util.Map.of("downloadUrl", downloadUrl)));
    }

    // ==================== Save to Device ====================

    /**
     * Lưu file về thiết bị của người dùng.
     *
     * Luồng hoạt động:
     * 1. Người A gửi ảnh cho người B (message-service lưu mediaId)
     * 2. Người B nhấn "Lưu ảnh" → client gọi GET /api/v1/media/{id}/save
     * 3. Server tải file từ S3 → stream về client với header Content-Disposition: attachment
     * 4. Browser/mobile nhận byte stream → tự lưu vào thư mục Downloads/Gallery
     *
     * Đầu vào:
     * - id       (UUID, trên URL) : ID media cần lưu
     * - filename (String, optional) : Tên file khi lưu (mặc định: tên gốc hoặc media_{id})
     *
     * Đầu ra: Binary stream với headers:
     * - Content-Type: mime type gốc (image/jpeg, video/mp4...)
     * - Content-Disposition: attachment; filename="ten_file.jpg"
     * - Content-Length: kích thước file
     */
    @GetMapping("/{id}/save")
    public ResponseEntity<byte[]> saveToDevice(
            Authentication authentication,
            @PathVariable UUID id,
            @RequestParam(value = "filename", required = false) String filename
    ) {
        UUID userId = getUserId(authentication);

        // Kiểm tra quyền — chỉ owner và user được cấp quyền mới được lưu
        if (!mediaAccessService.canAccess(id, userId)) {
            throw new AccessDeniedException("Bạn không có quyền tải media này");
        }

        MediaObject media = mediaService.getMedia(id);

        // Tải byte stream từ S3
        byte[] fileBytes = mediaService.downloadMediaBytes(id);

        // Xác định tên file để lưu
        String saveFilename = (filename != null && !filename.isBlank())
                ? filename
                : (media.getOriginalFilename() != null
                        ? media.getOriginalFilename()
                        : "media_" + id);

        // Đảm bảo tên file không chứa ký tự đặc biệt
        saveFilename = saveFilename.replaceAll("[^a-zA-Z0-9._\\-\\u00C0-\\u024F]", "_");

        org.springframework.http.HttpHeaders headers = new org.springframework.http.HttpHeaders();
        // Content-Disposition: attachment → browser/mobile kích hoạt dialog lưu file
        headers.add(org.springframework.http.HttpHeaders.CONTENT_DISPOSITION,
                "attachment; filename=\"" + saveFilename + "\"");
        headers.add(org.springframework.http.HttpHeaders.CONTENT_TYPE, media.getMimeType());
        headers.add(org.springframework.http.HttpHeaders.CONTENT_LENGTH, String.valueOf(fileBytes.length));
        // Cho phép frontend đọc header này trong browser
        headers.add("Access-Control-Expose-Headers", "Content-Disposition");

        log.info("User {} downloading media {} ({}bytes)", userId, id, fileBytes.length);

        return ResponseEntity.ok()
                .headers(headers)
                .body(fileBytes);
    }

    // ==================== Thumbnail ====================

    /**
     * Lấy thumbnail URL. Nếu có thumbnailUrl → redirect, nếu không → trả về URL gốc.
     *
     * Đầu vào:
     * - id (UUID, trên URL) : ID media
     *
     * Đầu ra: 302 Redirect đến thumbnail URL, hoặc 200 với URL gốc nếu chưa có thumbnail
     */
    @GetMapping("/{id}/thumbnail")
    public ResponseEntity<?> getThumbnail(
            Authentication authentication,
            @PathVariable UUID id
    ) {
        UUID userId = getUserId(authentication);

        if (!mediaAccessService.canAccess(id, userId)) {
            throw new AccessDeniedException("Bạn không có quyền truy cập media này");
        }

        MediaObject media = mediaService.getMedia(id);
        String thumbnailUrl = media.getThumbnailUrl();

        if (thumbnailUrl != null && !thumbnailUrl.isBlank()) {
            return ResponseEntity.status(HttpStatus.FOUND)
                    .header("Location", thumbnailUrl)
                    .build();
        }

        // No thumbnail — return original URL
        return ResponseEntity.ok(ApiResponse.ok(java.util.Map.of(
                "url", media.getUrl(),
                "message", "Thumbnail chưa được tạo, trả về URL gốc")));
    }

    // ==================== Status ====================

    /**
     * Lấy status hiện tại của media.
     *
     * Đầu vào:
     * - id (UUID, trên URL) : ID media
     *
     * Đầu ra (200 OK): JSON chứa id, status, expiresAt
     */
    @GetMapping("/{id}/status")
    public ResponseEntity<ApiResponse<java.util.Map<String, Object>>> getMediaStatus(
            Authentication authentication,
            @PathVariable UUID id
    ) {
        MediaObject media = mediaService.getMedia(id);

        java.util.Map<String, Object> statusInfo = new java.util.LinkedHashMap<>();
        statusInfo.put("id", media.getId());
        statusInfo.put("status", media.getStatus());
        statusInfo.put("expiresAt", media.getExpiresAt());
        statusInfo.put("createdAt", media.getCreatedAt());

        return ResponseEntity.ok(ApiResponse.ok(statusInfo));
    }

    // ==================== Hàm hỗ trợ ====================

    /**
     * Lấy userId từ JWT token (đã được JwtAuthenticationFilter xử lý sẵn).
     * Không cần parse JWT thủ công — userId nằm trong SecurityContext.
     */
    private UUID getUserId(Authentication authentication) {
        return UUID.fromString(authentication.getPrincipal().toString());
    }
}
