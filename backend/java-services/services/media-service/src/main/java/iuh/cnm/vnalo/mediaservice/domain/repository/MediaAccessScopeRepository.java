package iuh.cnm.vnalo.mediaservice.domain.repository;

import iuh.cnm.vnalo.mediaservice.domain.model.MediaAccessScope;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface MediaAccessScopeRepository extends JpaRepository<MediaAccessScope, MediaAccessScope.MediaAccessScopeId> {

    List<MediaAccessScope> findByMediaId(UUID mediaId);

    void deleteByMediaId(UUID mediaId);
}
