package iuh.cnm.vnalo.mediaservice.controller;

import iuh.cnm.vnalo.mediaservice.domain.dto.*;
import iuh.cnm.vnalo.mediaservice.domain.model.StickerPackCategory;
import iuh.cnm.vnalo.mediaservice.service.StickerService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.UUID;

/**
 * Controller quản lý Sticker.
 *
 * Chức năng:
 * - CRUD sticker pack
 * - Upload/xóa sticker trong pack
 * - Tìm kiếm sticker theo keyword/emoji
 * - User tải/bỏ pack, xem pack đã tải
 * - Ghi nhận sử dụng, xem sticker gần đây
 */
@RestController
@RequestMapping("/api/v1/stickers")
@RequiredArgsConstructor
@Slf4j
public class StickerController {

    private final StickerService stickerService;

    // ==================== PACK ====================

    /**
     * List tất cả sticker pack đang active.
     * Có thể filter theo category.
     */
    @GetMapping("/packs")
    public ResponseEntity<ApiResponse<Page<StickerPackResponse>>> listPacks(
            @RequestParam(required = false) StickerPackCategory category,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {

        Page<StickerPackResponse> packs = stickerService.listPacks(category, page, size);
        return ResponseEntity.ok(ApiResponse.ok(packs));
    }

    /**
     * Lấy chi tiết 1 pack + danh sách sticker bên trong.
     */
    @GetMapping("/packs/{packId}")
    public ResponseEntity<ApiResponse<StickerPackDetailResponse>> getPackDetail(
            @PathVariable UUID packId) {

        StickerPackDetailResponse detail = stickerService.getPackDetail(packId);
        return ResponseEntity.ok(ApiResponse.ok(detail));
    }

    /**
     * Tạo sticker pack mới.
     * Body: form-data với JSON fields + file thumbnail.
     */
    @PostMapping("/packs")
    public ResponseEntity<ApiResponse<StickerPackResponse>> createPack(
            @RequestPart("thumbnail") MultipartFile thumbnail,
            @RequestPart("name") String name,
            @RequestPart(value = "description", required = false) String description,
            @RequestPart(value = "author", required = false) String author,
            @RequestPart(value = "category", required = false) String category,
            Authentication authentication) {

        String userId = authentication.getName();

        CreateStickerPackRequest request = new CreateStickerPackRequest();
        request.setName(name);
        request.setDescription(description);
        request.setAuthor(author);
        if (category != null) {
            request.setCategory(StickerPackCategory.valueOf(category.toUpperCase()));
        }

        StickerPackResponse response = stickerService.createPack(request, thumbnail, userId);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(response));
    }

    /**
     * Update thông tin pack (tên, mô tả, category...).
     */
    @PatchMapping("/packs/{packId}")
    public ResponseEntity<ApiResponse<StickerPackResponse>> updatePack(
            @PathVariable UUID packId,
            @RequestBody @Valid CreateStickerPackRequest request) {

        StickerPackResponse response = stickerService.updatePack(packId, request);
        return ResponseEntity.ok(ApiResponse.ok(response));
    }

    /**
     * Xóa pack (soft delete → status = DELETED).
     */
    @DeleteMapping("/packs/{packId}")
    public ResponseEntity<ApiResponse<Void>> deletePack(@PathVariable UUID packId) {

        stickerService.deletePack(packId);
        return ResponseEntity.ok(ApiResponse.ok(null));
    }

    // ==================== STICKER ====================

    /**
     * Upload sticker vào pack.
     * Body: form-data với file + metadata.
     */
    @PostMapping("/packs/{packId}/stickers")
    public ResponseEntity<ApiResponse<StickerResponse>> addSticker(
            @PathVariable UUID packId,
            @RequestPart("file") MultipartFile file,
            @RequestPart(value = "name", required = false) String name,
            @RequestPart(value = "emojiMatch", required = false) String emojiMatch,
            @RequestPart(value = "keywords", required = false) List<String> keywords,
            @RequestParam(value = "orderIndex", required = false) Integer orderIndex) {

        StickerResponse response = stickerService.addSticker(packId, file, name, emojiMatch, keywords, orderIndex);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(response));
    }

    /**
     * Lấy thông tin 1 sticker.
     */
    @GetMapping("/{stickerId}")
    public ResponseEntity<ApiResponse<StickerResponse>> getSticker(@PathVariable UUID stickerId) {

        StickerResponse response = stickerService.getSticker(stickerId);
        return ResponseEntity.ok(ApiResponse.ok(response));
    }

    /**
     * Xóa 1 sticker.
     */
    @DeleteMapping("/{stickerId}")
    public ResponseEntity<ApiResponse<Void>> deleteSticker(@PathVariable UUID stickerId) {

        stickerService.deleteSticker(stickerId);
        return ResponseEntity.ok(ApiResponse.ok(null));
    }

    /**
     * Tìm sticker theo keyword hoặc emoji.
     */
    @GetMapping("/search")
    public ResponseEntity<ApiResponse<List<StickerResponse>>> searchStickers(
            @RequestParam String keyword) {

        List<StickerResponse> results = stickerService.searchStickers(keyword);
        return ResponseEntity.ok(ApiResponse.ok(results));
    }

    // ==================== USER PACK ====================

    /**
     * User tải/thêm 1 pack vào danh sách của mình.
     */
    @PostMapping("/packs/{packId}/download")
    public ResponseEntity<ApiResponse<Void>> downloadPack(
            @PathVariable UUID packId,
            Authentication authentication) {

        UUID userId = UUID.fromString(authentication.getName());
        stickerService.downloadPack(packId, userId);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(null));
    }

    /**
     * User bỏ pack khỏi danh sách.
     */
    @DeleteMapping("/packs/{packId}/download")
    public ResponseEntity<ApiResponse<Void>> removePack(
            @PathVariable UUID packId,
            Authentication authentication) {

        UUID userId = UUID.fromString(authentication.getName());
        stickerService.removePack(packId, userId);
        return ResponseEntity.ok(ApiResponse.ok(null));
    }

    /**
     * Xem danh sách pack mà user đã tải.
     */
    @GetMapping("/my-packs")
    public ResponseEntity<ApiResponse<List<StickerPackResponse>>> getMyPacks(
            Authentication authentication) {

        UUID userId = UUID.fromString(authentication.getName());
        List<StickerPackResponse> packs = stickerService.getMyPacks(userId);
        return ResponseEntity.ok(ApiResponse.ok(packs));
    }

    // ==================== USAGE ====================

    /**
     * Ghi nhận user sử dụng sticker (tăng usage_count).
     */
    @PostMapping("/{stickerId}/use")
    public ResponseEntity<ApiResponse<Void>> recordUsage(
            @PathVariable UUID stickerId,
            Authentication authentication) {

        UUID userId = UUID.fromString(authentication.getName());
        stickerService.recordUsage(stickerId, userId);
        return ResponseEntity.ok(ApiResponse.ok(null));
    }

    /**
     * Lấy sticker user dùng gần đây nhất.
     */
    @GetMapping("/recent")
    public ResponseEntity<ApiResponse<List<StickerResponse>>> getRecentStickers(
            @RequestParam(defaultValue = "20") int limit,
            Authentication authentication) {

        UUID userId = UUID.fromString(authentication.getName());
        List<StickerResponse> stickers = stickerService.getRecentStickers(userId, limit);
        return ResponseEntity.ok(ApiResponse.ok(stickers));
    }
}
