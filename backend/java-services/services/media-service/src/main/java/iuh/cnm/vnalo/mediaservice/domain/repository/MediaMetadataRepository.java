package iuh.cnm.vnalo.mediaservice.domain.repository;

import iuh.cnm.vnalo.mediaservice.domain.model.MediaCategory;
import iuh.cnm.vnalo.mediaservice.domain.model.MediaMetadata;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.UUID;

@Repository
public interface MediaMetadataRepository extends JpaRepository<MediaMetadata, UUID> {

    Page<MediaMetadata> findByOwnerUserId(UUID ownerUserId, Pageable pageable);

    Page<MediaMetadata> findByOwnerUserIdAndCategory(UUID ownerUserId, MediaCategory category, Pageable pageable);

    Page<MediaMetadata> findByCategory(MediaCategory category, Pageable pageable);
}
