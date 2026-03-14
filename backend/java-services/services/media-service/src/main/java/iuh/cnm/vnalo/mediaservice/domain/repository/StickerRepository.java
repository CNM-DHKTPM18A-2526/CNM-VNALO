package iuh.cnm.vnalo.mediaservice.domain.repository;

import iuh.cnm.vnalo.mediaservice.domain.model.Sticker;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.UUID;

public interface StickerRepository extends JpaRepository<Sticker, UUID> {

    List<Sticker> findByPackIdOrderByOrderIndex(UUID packId);

    int countByPackId(UUID packId);

    void deleteByPackId(UUID packId);

    @Query("SELECT s FROM Sticker s WHERE s.emojiMatch LIKE %:keyword% " +
            "OR CAST(s.keywords AS string) LIKE %:keyword%")
    List<Sticker> searchByKeyword(@Param("keyword") String keyword);
}
