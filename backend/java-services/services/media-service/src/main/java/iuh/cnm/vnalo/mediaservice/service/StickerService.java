package iuh.cnm.vnalo.mediaservice.service;

import iuh.cnm.vnalo.mediaservice.domain.dto.*;
import iuh.cnm.vnalo.mediaservice.domain.model.*;
import iuh.cnm.vnalo.mediaservice.domain.repository.*;
import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class StickerService {

    private final StickerPackRepository stickerPackRepository;
    private final StickerRepository stickerRepository;
    private final UserStickerPackRepository userStickerPackRepository;
    private final StickerUsageRepository stickerUsageRepository;
    private final S3Service s3Service;

    // ==================== PACK ====================

    public Page<StickerPackResponse> listPacks(StickerPackCategory category, int page, int size) {
        Pageable pageable = PageRequest.of(page, size, Sort.by("downloadCount").descending());

        Page<StickerPack> packs;
        if (category != null) {
            packs = stickerPackRepository.findByStatusAndCategory(StickerPackStatus.ACTIVE, category, pageable);
        } else {
            packs = stickerPackRepository.findByStatus(StickerPackStatus.ACTIVE, pageable);
        }

        return packs.map(StickerPackResponse::from);
    }

    public StickerPackDetailResponse getPackDetail(UUID packId) {
        StickerPack pack = findPackOrThrow(packId);

        List<StickerResponse> stickers = stickerRepository.findByPackIdOrderByOrderIndex(packId)
                .stream()
                .map(StickerResponse::from)
                .toList();

        return StickerPackDetailResponse.from(pack, stickers);
    }

    @Transactional
    public StickerPackResponse createPack(CreateStickerPackRequest request, MultipartFile thumbnail, String userId) {
        String thumbnailKey = "stickers/packs/" + UUID.randomUUID() + "_thumb.png";
        String thumbnailUrl = s3Service.uploadFile(thumbnail, thumbnailKey);

        StickerPack pack = StickerPack.builder()
                .name(request.getName())
                .description(request.getDescription())
                .thumbnailUrl(thumbnailUrl)
                .author(request.getAuthor())
                .category(request.getCategory() != null ? request.getCategory() : StickerPackCategory.CUSTOM)
                .isPremium(request.getIsPremium() != null ? request.getIsPremium() : false)
                .isAnimated(request.getIsAnimated() != null ? request.getIsAnimated() : false)
                .price(request.getPrice())
                .build();

        StickerPack saved = stickerPackRepository.save(pack);
        log.info("Created sticker pack: {} by user {}", saved.getPackId(), userId);
        return StickerPackResponse.from(saved);
    }

    @Transactional
    public StickerPackResponse updatePack(UUID packId, CreateStickerPackRequest request) {
        StickerPack pack = findPackOrThrow(packId);

        if (request.getName() != null) pack.setName(request.getName());
        if (request.getDescription() != null) pack.setDescription(request.getDescription());
        if (request.getAuthor() != null) pack.setAuthor(request.getAuthor());
        if (request.getCategory() != null) pack.setCategory(request.getCategory());
        if (request.getIsPremium() != null) pack.setIsPremium(request.getIsPremium());
        if (request.getIsAnimated() != null) pack.setIsAnimated(request.getIsAnimated());
        if (request.getPrice() != null) pack.setPrice(request.getPrice());

        StickerPack saved = stickerPackRepository.save(pack);
        return StickerPackResponse.from(saved);
    }

    @Transactional
    public void deletePack(UUID packId) {
        StickerPack pack = findPackOrThrow(packId);
        pack.setStatus(StickerPackStatus.DELETED);
        stickerPackRepository.save(pack);
        log.info("Soft-deleted sticker pack: {}", packId);
    }

    // ==================== STICKER ====================

    @Transactional
    public StickerResponse addSticker(UUID packId, MultipartFile file, String name,
                                       String emojiMatch, List<String> keywords, Integer orderIndex) {
        StickerPack pack = findPackOrThrow(packId);

        // Xác định file type
        String originalFilename = file.getOriginalFilename();
        StickerFileType fileType = detectFileType(originalFilename);

        // Upload lên S3
        String key = "stickers/" + packId + "/" + UUID.randomUUID() + "." + fileType.name().toLowerCase();
        String imageUrl = s3Service.uploadFile(file, key);

        Sticker sticker = Sticker.builder()
                .packId(packId)
                .name(name)
                .imageUrl(imageUrl)
                .fileType(fileType)
                .emojiMatch(emojiMatch)
                .keywords(keywords)
                .orderIndex(orderIndex != null ? orderIndex : pack.getStickerCount())
                .build();

        Sticker saved = stickerRepository.save(sticker);

        // Cập nhật sticker_count
        pack.setStickerCount(pack.getStickerCount() + 1);
        stickerPackRepository.save(pack);

        log.info("Added sticker {} to pack {}", saved.getStickerId(), packId);
        return StickerResponse.from(saved);
    }

    public StickerResponse getSticker(UUID stickerId) {
        Sticker sticker = stickerRepository.findById(stickerId)
                .orElseThrow(() -> new EntityNotFoundException("Sticker not found: " + stickerId));
        return StickerResponse.from(sticker);
    }

    @Transactional
    public void deleteSticker(UUID stickerId) {
        Sticker sticker = stickerRepository.findById(stickerId)
                .orElseThrow(() -> new EntityNotFoundException("Sticker not found: " + stickerId));

        // Giảm sticker_count
        stickerPackRepository.findById(sticker.getPackId()).ifPresent(pack -> {
            pack.setStickerCount(Math.max(0, pack.getStickerCount() - 1));
            stickerPackRepository.save(pack);
        });

        stickerRepository.delete(sticker);
        log.info("Deleted sticker: {}", stickerId);
    }

    public List<StickerResponse> searchStickers(String keyword) {
        return stickerRepository.searchByKeyword(keyword)
                .stream()
                .map(StickerResponse::from)
                .toList();
    }

    // ==================== USER PACK ====================

    @Transactional
    public void downloadPack(UUID packId, UUID userId) {
        findPackOrThrow(packId);

        if (userStickerPackRepository.existsByUserIdAndPackId(userId, packId)) {
            throw new IllegalStateException("Pack đã được tải trước đó");
        }

        int currentCount = userStickerPackRepository.findByUserIdOrderByOrderIndex(userId).size();

        UserStickerPack userPack = UserStickerPack.builder()
                .userId(userId)
                .packId(packId)
                .orderIndex(currentCount)
                .build();

        userStickerPackRepository.save(userPack);

        // Tăng download_count
        stickerPackRepository.findById(packId).ifPresent(pack -> {
            pack.setDownloadCount(pack.getDownloadCount() + 1);
            stickerPackRepository.save(pack);
        });

        log.info("User {} downloaded pack {}", userId, packId);
    }

    @Transactional
    public void removePack(UUID packId, UUID userId) {
        userStickerPackRepository.deleteByUserIdAndPackId(userId, packId);
        log.info("User {} removed pack {}", userId, packId);
    }

    public List<StickerPackResponse> getMyPacks(UUID userId) {
        List<UUID> packIds = userStickerPackRepository.findByUserIdOrderByOrderIndex(userId)
                .stream()
                .map(UserStickerPack::getPackId)
                .toList();

        return stickerPackRepository.findAllById(packIds)
                .stream()
                .filter(p -> p.getStatus() == StickerPackStatus.ACTIVE)
                .map(StickerPackResponse::from)
                .toList();
    }

    // ==================== USAGE ====================

    @Transactional
    public void recordUsage(UUID stickerId, UUID userId) {
        // Kiểm tra sticker tồn tại
        if (!stickerRepository.existsById(stickerId)) {
            throw new EntityNotFoundException("Sticker not found: " + stickerId);
        }

        StickerUsage usage = stickerUsageRepository
                .findByUserIdAndStickerId(userId, stickerId)
                .map(existing -> {
                    existing.setUsageCount(existing.getUsageCount() + 1);
                    return existing;
                })
                .orElse(StickerUsage.builder()
                        .userId(userId)
                        .stickerId(stickerId)
                        .usageCount(1)
                        .lastUsedAt(LocalDateTime.now())
                        .build());

        stickerUsageRepository.save(usage);
    }

    public List<StickerResponse> getRecentStickers(UUID userId, int limit) {
        List<StickerUsage> usages = stickerUsageRepository
                .findByUserIdOrderByLastUsedAtDesc(userId, PageRequest.of(0, limit));

        List<UUID> stickerIds = usages.stream()
                .map(StickerUsage::getStickerId)
                .toList();

        return stickerRepository.findAllById(stickerIds)
                .stream()
                .map(StickerResponse::from)
                .toList();
    }

    // ==================== HELPER ====================

    private StickerPack findPackOrThrow(UUID packId) {
        StickerPack pack = stickerPackRepository.findById(packId)
                .orElseThrow(() -> new EntityNotFoundException("Sticker pack not found: " + packId));
        if (pack.getStatus() == StickerPackStatus.DELETED) {
            throw new EntityNotFoundException("Sticker pack not found: " + packId);
        }
        return pack;
    }

    private StickerFileType detectFileType(String filename) {
        if (filename == null) return StickerFileType.PNG;
        String lower = filename.toLowerCase();
        if (lower.endsWith(".gif")) return StickerFileType.GIF;
        if (lower.endsWith(".webp")) return StickerFileType.WEBP;
        if (lower.endsWith(".json")) return StickerFileType.LOTTIE;
        return StickerFileType.PNG;
    }
}
