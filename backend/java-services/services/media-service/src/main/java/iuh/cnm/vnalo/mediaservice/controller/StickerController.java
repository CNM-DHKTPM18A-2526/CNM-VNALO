package iuh.cnm.vnalo.mediaservice.controller;

import iuh.cnm.vnalo.mediaservice.domain.dto.*;
import iuh.cnm.vnalo.mediaservice.service.StickerService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/stickers")
@RequiredArgsConstructor
@Slf4j
public class StickerController {

    private final StickerService stickerService;

    // ==================== PACK ====================

    @GetMapping("/packs")
    public ResponseEntity<ApiResponse<Page<StickerPackResponse>>> listPacks(
            @RequestParam(value = "category", required = false) String category,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {

        Page<StickerPackResponse> packs = stickerService.listPacks(page, size);
        return ResponseEntity.ok(ApiResponse.ok(packs));
    }

    @GetMapping("/packs/{packId}")
    public ResponseEntity<ApiResponse<StickerPackDetailResponse>> getPackDetail(
            @PathVariable UUID packId) {

        StickerPackDetailResponse detail = stickerService.getPackDetail(packId);
        return ResponseEntity.ok(ApiResponse.ok(detail));
    }

    @PostMapping("/packs")
    public ResponseEntity<ApiResponse<StickerPackResponse>> createPack(
            @RequestBody @Valid CreateStickerPackRequest request,
            Authentication authentication) {

        UUID userId = UUID.fromString(authentication.getName());
        StickerPackResponse response = stickerService.createPack(request, userId);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(response));
    }

    @PatchMapping("/packs/{packId}")
    public ResponseEntity<ApiResponse<StickerPackResponse>> updatePack(
            @PathVariable UUID packId,
            @RequestBody Map<String, Object> updates,
            Authentication authentication) {

        UUID userId = UUID.fromString(authentication.getName());
        StickerPackResponse response = stickerService.updatePack(packId, updates, userId);
        return ResponseEntity.ok(ApiResponse.ok(response));
    }

    @DeleteMapping("/packs/{packId}")
    public ResponseEntity<ApiResponse<Void>> deletePack(@PathVariable UUID packId) {
        stickerService.deletePack(packId);
        return ResponseEntity.ok(ApiResponse.ok(null));
    }

    // ==================== STICKER ====================

    @PostMapping("/packs/{packId}/stickers")
    public ResponseEntity<ApiResponse<StickerResponse>> addSticker(
            @PathVariable UUID packId,
            @RequestParam("mediaId") UUID mediaId,
            @RequestParam(value = "name", required = false) String name,
            @RequestParam(value = "isAnimated", defaultValue = "false") Boolean isAnimated,
            @RequestParam(value = "displayOrder", required = false) Integer displayOrder) {

        StickerResponse response = stickerService.addSticker(packId, mediaId, name, isAnimated, displayOrder);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(response));
    }

    @GetMapping("/{stickerId}")
    public ResponseEntity<ApiResponse<StickerResponse>> getSticker(@PathVariable UUID stickerId) {
        StickerResponse response = stickerService.getSticker(stickerId);
        return ResponseEntity.ok(ApiResponse.ok(response));
    }

    @DeleteMapping("/{stickerId}")
    public ResponseEntity<ApiResponse<Void>> deleteSticker(@PathVariable UUID stickerId) {
        stickerService.deleteSticker(stickerId);
        return ResponseEntity.ok(ApiResponse.ok(null));
    }

    @GetMapping("/search")
    public ResponseEntity<ApiResponse<List<StickerResponse>>> searchStickers(
            @RequestParam("keyword") String keyword) {

        List<StickerResponse> results = stickerService.searchStickers(keyword);
        return ResponseEntity.ok(ApiResponse.ok(results));
    }

    // ==================== USER COLLECTION ====================

    @PostMapping("/packs/{packId}/download")
    public ResponseEntity<ApiResponse<Void>> downloadPack(
            @PathVariable UUID packId,
            Authentication authentication) {

        UUID userId = UUID.fromString(authentication.getName());
        stickerService.installPack(packId, userId);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(null));
    }

    @DeleteMapping("/packs/{packId}/download")
    public ResponseEntity<ApiResponse<Void>> removePack(
            @PathVariable UUID packId,
            Authentication authentication) {

        UUID userId = UUID.fromString(authentication.getName());
        stickerService.uninstallPack(packId, userId);
        return ResponseEntity.ok(ApiResponse.ok(null));
    }

    @GetMapping("/my-packs")
    public ResponseEntity<ApiResponse<List<StickerPackResponse>>> getMyPacks(
            Authentication authentication) {

        UUID userId = UUID.fromString(authentication.getName());
        List<StickerPackResponse> packs = stickerService.getMyPacks(userId);
        return ResponseEntity.ok(ApiResponse.ok(packs));
    }

    // ==================== USAGE ====================

    @PostMapping("/{stickerId}/use")
    public ResponseEntity<ApiResponse<Void>> recordUsage(
            @PathVariable UUID stickerId,
            Authentication authentication) {

        UUID userId = UUID.fromString(authentication.getName());
        stickerService.recordUsage(stickerId, userId);
        return ResponseEntity.ok(ApiResponse.ok(null));
    }

    @GetMapping("/recent")
    public ResponseEntity<ApiResponse<List<StickerResponse>>> getRecentStickers(
            @RequestParam(defaultValue = "20") int limit,
            Authentication authentication) {

        UUID userId = UUID.fromString(authentication.getName());
        List<StickerResponse> stickers = stickerService.getRecentStickers(userId, limit);
        return ResponseEntity.ok(ApiResponse.ok(stickers));
    }
}
