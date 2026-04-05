package iuh.cnm.vnalo.mediaservice.controller;

import iuh.cnm.vnalo.mediaservice.domain.model.MediaCategory;
import iuh.cnm.vnalo.mediaservice.domain.model.MediaMetadata;
import iuh.cnm.vnalo.mediaservice.exception.AccessDeniedException;
import iuh.cnm.vnalo.mediaservice.service.MediaAccessService;
import iuh.cnm.vnalo.mediaservice.service.MediaService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.core.Authentication;

import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class MediaControllerAuthorizationTest {

    @Mock
    private MediaService mediaService;

    @Mock
    private MediaAccessService mediaAccessService;

    @Mock
    private Authentication authentication;

    @InjectMocks
    private MediaController mediaController;

    @Test
    void getMediaInfo_shouldThrowForbiddenWhenUserCannotAccess() {
        UUID mediaId = UUID.randomUUID();
        UUID userId = UUID.randomUUID();

        when(authentication.getPrincipal()).thenReturn(userId.toString());
        when(mediaAccessService.canAccess(mediaId, userId)).thenReturn(false);

        assertThrows(AccessDeniedException.class, () -> mediaController.getMediaInfo(authentication, mediaId));
        verify(mediaService, never()).getMedia(any());
    }

    @Test
    void listMedia_shouldAlwaysUseAuthenticatedUserAsOwner() {
        UUID authUserId = UUID.randomUUID();
        UUID requestedOwner = UUID.randomUUID();

        when(authentication.getPrincipal()).thenReturn(authUserId.toString());
        when(mediaService.listMedia(eq(authUserId), eq(MediaCategory.CHAT_IMAGE), any())).thenReturn(org.springframework.data.domain.Page.empty());

        mediaController.listMedia(authentication, requestedOwner, MediaCategory.CHAT_IMAGE, 0, 20);

        verify(mediaService).listMedia(eq(authUserId), eq(MediaCategory.CHAT_IMAGE), any());
        verify(mediaService, never()).listMedia(eq(requestedOwner), eq(MediaCategory.CHAT_IMAGE), any());
    }

    @Test
    void grantAccess_shouldThrowForbiddenWhenCallerIsNotOwner() {
        UUID mediaId = UUID.randomUUID();
        UUID ownerId = UUID.randomUUID();
        UUID callerId = UUID.randomUUID();

        when(authentication.getPrincipal()).thenReturn(callerId.toString());
        when(mediaService.getMedia(mediaId)).thenReturn(MediaMetadata.builder()
                .id(mediaId)
                .ownerUserId(ownerId)
                .category(MediaCategory.CHAT_IMAGE)
                .bucket("bucket")
                .objectKey("obj")
                .mimeType("image/png")
                .sizeBytes(10L)
                .build());

        assertThrows(AccessDeniedException.class,
                () -> mediaController.grantAccess(authentication, mediaId, new iuh.cnm.vnalo.mediaservice.domain.dto.AccessScopeRequest()));
    }
}
