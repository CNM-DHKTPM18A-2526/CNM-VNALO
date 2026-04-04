package iuh.cnm.vnalo.mediaservice.domain.repository;

import iuh.cnm.vnalo.mediaservice.domain.model.UserStickerPack;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface UserStickerPackRepository extends JpaRepository<UserStickerPack, UserStickerPack.UserStickerPackId> {

    List<UserStickerPack> findByUserIdOrderByPinnedOrder(UUID userId);

    boolean existsByUserIdAndPackId(UUID userId, UUID packId);

    void deleteByUserIdAndPackId(UUID userId, UUID packId);
}
