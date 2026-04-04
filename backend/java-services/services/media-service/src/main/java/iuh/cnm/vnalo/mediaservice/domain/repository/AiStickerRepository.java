package iuh.cnm.vnalo.mediaservice.domain.repository;

import iuh.cnm.vnalo.mediaservice.domain.model.AiSticker;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface AiStickerRepository extends JpaRepository<AiSticker, UUID> {

    List<AiSticker> findByUserIdOrderByCreatedAtDesc(UUID userId);
}
