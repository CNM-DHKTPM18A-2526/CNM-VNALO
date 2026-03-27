package iuh.cnm.vnalo.mediaservice.service;

import iuh.cnm.vnalo.mediaservice.domain.model.MediaAccessScope;
import iuh.cnm.vnalo.mediaservice.domain.model.MediaMetadata;
import iuh.cnm.vnalo.mediaservice.domain.model.ScopeType;
import iuh.cnm.vnalo.mediaservice.domain.repository.MediaAccessScopeRepository;
import iuh.cnm.vnalo.mediaservice.domain.repository.MediaMetadataRepository;
import iuh.cnm.vnalo.mediaservice.exception.ResourceNotFoundException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

/**
 * Manages media access control using MediaAccessScope.
 * Determines who can view which media based on scope rules:
 * - PUBLIC: anyone can view
 * - USER: specific user can view
 * - CONVERSATION: members of a conversation can view
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class MediaAccessService {

    private final MediaAccessScopeRepository accessScopeRepository;
    private final MediaMetadataRepository mediaMetadataRepository;

    /**
     * Grant access to a media object for a specific scope.
     */
    @Transactional
    public MediaAccessScope grantAccess(UUID mediaId, ScopeType scopeType, UUID scopeId) {
        // Verify media exists
        mediaMetadataRepository.findById(mediaId)
                .orElseThrow(() -> new ResourceNotFoundException("Media not found: " + mediaId));

        MediaAccessScope scope = MediaAccessScope.builder()
                .mediaId(mediaId)
                .scopeType(scopeType)
                .scopeId(scopeId)
                .build();

        return accessScopeRepository.save(scope);
    }

    /**
     * Revoke access to a media object for a specific scope.
     */
    @Transactional
    public void revokeAccess(UUID mediaId, ScopeType scopeType, UUID scopeId) {
        MediaAccessScope.MediaAccessScopeId id = new MediaAccessScope.MediaAccessScopeId(mediaId, scopeType, scopeId);
        accessScopeRepository.deleteById(id);
    }

    /**
     * Check if a user can access a media object.
     * Access is granted if:
     * 1. User is the owner of the media
     * 2. Media has a PUBLIC scope
     * 3. User has a USER scope for this media
     * 4. User is in a CONVERSATION scope for this media (scopeId = conversationId, need to be checked by caller)
     */
    public boolean canAccess(UUID mediaId, UUID userId) {
        MediaMetadata media = mediaMetadataRepository.findById(mediaId)
                .orElseThrow(() -> new ResourceNotFoundException("Media not found: " + mediaId));

        // Owner always has access
        if (media.getOwnerUserId().equals(userId)) {
            return true;
        }

        // Check access scopes
        List<MediaAccessScope> scopes = accessScopeRepository.findByMediaId(mediaId);

        for (MediaAccessScope scope : scopes) {
            switch (scope.getScopeType()) {
                case PUBLIC:
                    return true;
                case USER:
                    if (scope.getScopeId().equals(userId)) {
                        return true;
                    }
                    break;
                case CONVERSATION:
                    // For CONVERSATION scope, the scopeId is the conversationId.
                    // The userId is also stored as scopeId for user-level conversation access.
                    // In practice, the calling service passes the conversationId and we check membership.
                    if (scope.getScopeId().equals(userId)) {
                        return true;
                    }
                    break;
            }
        }

        return false;
    }

    /**
     * Get all access scopes for a media object.
     */
    public List<MediaAccessScope> getAccessScopes(UUID mediaId) {
        return accessScopeRepository.findByMediaId(mediaId);
    }
}
