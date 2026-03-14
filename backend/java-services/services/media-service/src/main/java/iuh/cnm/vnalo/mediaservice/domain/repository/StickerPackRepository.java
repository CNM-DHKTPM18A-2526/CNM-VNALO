package iuh.cnm.vnalo.mediaservice.domain.repository;

import iuh.cnm.vnalo.mediaservice.domain.model.StickerPack;
import iuh.cnm.vnalo.mediaservice.domain.model.StickerPackCategory;
import iuh.cnm.vnalo.mediaservice.domain.model.StickerPackStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface StickerPackRepository extends JpaRepository<StickerPack, UUID> {

    Page<StickerPack> findByStatus(StickerPackStatus status, Pageable pageable);

    Page<StickerPack> findByStatusAndCategory(StickerPackStatus status, StickerPackCategory category, Pageable pageable);

    List<StickerPack> findByStatusOrderByDownloadCountDesc(StickerPackStatus status);
}
