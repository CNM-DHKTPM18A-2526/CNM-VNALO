package iuh.cnm.vnalo.mediaservice.domain.repository;

import iuh.cnm.vnalo.mediaservice.domain.model.StickerUsage;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface StickerUsageRepository extends JpaRepository<StickerUsage, StickerUsage.StickerUsageId> {

    List<StickerUsage> findByUserIdOrderByLastUsedAtDesc(UUID userId, Pageable pageable);

    Optional<StickerUsage> findByUserIdAndStickerId(UUID userId, UUID stickerId);
}
