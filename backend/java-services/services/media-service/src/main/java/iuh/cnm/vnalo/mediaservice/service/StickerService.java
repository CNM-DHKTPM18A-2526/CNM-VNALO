package iuh.cnm.vnalo.mediaservice.service;

import iuh.cnm.vnalo.mediaservice.domain.dto.*;
import iuh.cnm.vnalo.mediaservice.domain.model.*;
import iuh.cnm.vnalo.mediaservice.domain.repository.*;
import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

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

    // ==================== PACK ====================

    @Cacheable(value = "stickerPacks", key = "#page + '-' + #size")
    public Page<StickerPackResponse> listPacks(int page, int size) {
        Pageable pageable = PageRequest.of(page, size, Sort.by("downloadCount").descending());
        Page<StickerPack> packs = stickerPackRepository.findByStatus(StickerPackStatus.PUBLISHED, pageable);
        return packs.map(StickerPackResponse::from);
    }

    public StickerPackDetailResponse getPackDetail(UUID packId) {
        StickerPack pack = findPackOrThrow(packId);

        List<StickerResponse> stickers = stickerRepository.findByPackIdOrderByDisplayOrder(packId)
                .stream()
                .map(StickerResponse::from)
                .toList();

        return StickerPackDetailResponse.from(pack, stickers);
    }

    @Transactional
    @CacheEvict(value = "stickerPacks", allEntries = true)
    public StickerPackResponse createPack(CreateStickerPackRequest request, UUID userId) {
        StickerPack pack = StickerPack.builder()
                .ownerUserId(userId)
                .name(request.getName())
                .description(request.getDescription())
                .coverMediaId(request.getCoverMediaId())
                .status(StickerPackStatus.DRAFT)
                .build();

        StickerPack saved = stickerPackRepository.save(pack);
        log.info("Created sticker pack: {} by user {}", saved.getStickerPackId(), userId);
        return StickerPackResponse.from(saved);
    }

    @Transactional
    @CacheEvict(value = "stickerPacks", allEntries = true)
    public void deletePack(UUID packId) {
        StickerPack pack = findPackOrThrow(packId);
        pack.setStatus(StickerPackStatus.SUSPENDED);
        stickerPackRepository.save(pack);
        log.info("Suspended sticker pack: {}", packId);
    }

    // ==================== STICKER ====================

    @Transactional
    public StickerResponse addSticker(UUID packId, UUID mediaId, String name,
                                       Boolean isAnimated, Integer displayOrder) {
        StickerPack pack = findPackOrThrow(packId);

        Sticker sticker = Sticker.builder()
                .packId(packId)
                .name(name)
                .mediaId(mediaId)
                .isAnimated(isAnimated != null ? isAnimated : false)
                .displayOrder(displayOrder != null ? displayOrder : pack.getStickerCount())
                .status(StickerStatus.ACTIVE)
                .build();

        Sticker saved = stickerRepository.save(sticker);

        pack.setStickerCount(pack.getStickerCount() + 1);
        stickerPackRepository.save(pack);

        log.info("Added sticker {} to pack {}", saved.getStickerId(), packId);
        return StickerResponse.from(saved);
    }

    @Transactional
    public void deleteSticker(UUID stickerId) {
        Sticker sticker = stickerRepository.findById(stickerId)
                .orElseThrow(() -> new EntityNotFoundException("Sticker not found: " + stickerId));

        stickerPackRepository.findById(sticker.getPackId()).ifPresent(pack -> {
            pack.setStickerCount(Math.max(0, pack.getStickerCount() - 1));
            stickerPackRepository.save(pack);
        });

        stickerRepository.delete(sticker);
        log.info("Deleted sticker: {}", stickerId);
    }

    // ==================== USER COLLECTION ====================

    @Transactional
    @CacheEvict(value = "stickerPacks", allEntries = true)
    public void installPack(UUID packId, UUID userId) {
        findPackOrThrow(packId);

        if (userStickerPackRepository.existsByUserIdAndPackId(userId, packId)) {
            throw new IllegalStateException("Pack đã được cài đặt trước đó");
        }

        UserStickerPack userPack = UserStickerPack.builder()
                .userId(userId)
                .packId(packId)
                .build();

        userStickerPackRepository.save(userPack);

        stickerPackRepository.findById(packId).ifPresent(pack -> {
            pack.setDownloadCount(pack.getDownloadCount() + 1);
            stickerPackRepository.save(pack);
        });

        log.info("User {} installed pack {}", userId, packId);
    }

    @Transactional
    public void uninstallPack(UUID packId, UUID userId) {
        userStickerPackRepository.deleteByUserIdAndPackId(userId, packId);
        log.info("User {} uninstalled pack {}", userId, packId);
    }

    public List<StickerPackResponse> getMyPacks(UUID userId) {
        List<UUID> packIds = userStickerPackRepository.findByUserIdOrderByPinnedOrder(userId)
                .stream()
                .map(UserStickerPack::getPackId)
                .toList();

        return stickerPackRepository.findAllById(packIds)
                .stream()
                .filter(p -> p.getStatus() == StickerPackStatus.PUBLISHED || p.getStatus() == StickerPackStatus.DRAFT)
                .map(StickerPackResponse::from)
                .toList();
    }

    // ==================== USAGE ====================

    @Transactional
    public void recordUsage(UUID stickerId, UUID userId) {
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

    // ==================== SINGLE STICKER ====================

    public StickerResponse getSticker(UUID stickerId) {
        Sticker sticker = stickerRepository.findById(stickerId)
                .orElseThrow(() -> new EntityNotFoundException("Sticker not found: " + stickerId));
        return StickerResponse.from(sticker);
    }

    // ==================== SEARCH ====================

    public List<StickerResponse> searchStickers(String keyword) {
        return stickerRepository.findByNameContainingIgnoreCaseAndStatus(keyword, StickerStatus.ACTIVE)
                .stream()
                .map(StickerResponse::from)
                .toList();
    }

    // ==================== UPDATE PACK ====================

    @Transactional
    @CacheEvict(value = "stickerPacks", allEntries = true)
    public StickerPackResponse updatePack(UUID packId, java.util.Map<String, Object> updates, UUID userId) {
        StickerPack pack = findPackOrThrow(packId);

        if (updates.containsKey("name")) {
            pack.setName((String) updates.get("name"));
        }
        if (updates.containsKey("description")) {
            pack.setDescription((String) updates.get("description"));
        }

        StickerPack saved = stickerPackRepository.save(pack);
        log.info("Updated sticker pack: {} by user {}", packId, userId);
        return StickerPackResponse.from(saved);
    }

    // ==================== HELPER ====================

    private StickerPack findPackOrThrow(UUID packId) {
        return stickerPackRepository.findById(packId)
                .orElseThrow(() -> new EntityNotFoundException("Sticker pack not found: " + packId));
    }
}
