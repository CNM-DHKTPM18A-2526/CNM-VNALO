package iuh.cnm.vnalo.mediaservice.domain.repository;

import iuh.cnm.vnalo.mediaservice.domain.model.Sticker;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface StickerRepository extends JpaRepository<Sticker, UUID> {

    List<Sticker> findByPackIdOrderByDisplayOrder(UUID packId);

    int countByPackId(UUID packId);

    void deleteByPackId(UUID packId);

    List<Sticker> findByNameContainingIgnoreCaseAndStatus(String name, iuh.cnm.vnalo.mediaservice.domain.model.StickerStatus status);
}
