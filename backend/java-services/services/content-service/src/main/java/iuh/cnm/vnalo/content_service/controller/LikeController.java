package iuh.cnm.vnalo.content_service.controller;

import iuh.cnm.vnalo.content_service.model.dto.PostLikeResponse;
import iuh.cnm.vnalo.content_service.service.LikeService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/posts/{postId}")
@RequiredArgsConstructor
public class LikeController {

    private final LikeService likeService;

    private UUID currentUserId(Authentication authentication) {
        return UUID.fromString(authentication.getName());
    }

    @PostMapping("/like")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void likePost(
            @PathVariable UUID postId,
            @RequestParam(defaultValue = "LOVE") String reactionType,
            Authentication authentication
    ) {
        likeService.likePost(postId, currentUserId(authentication), reactionType);
    }

    @DeleteMapping("/like")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unlikePost(
            @PathVariable UUID postId,
            Authentication authentication
    ) {
        likeService.unlikePost(postId, currentUserId(authentication));
    }

    @GetMapping("/likes")
    public List<PostLikeResponse> getPostLikers(
            @PathVariable UUID postId,
            Authentication authentication
    ) {
        return likeService.getPostLikers(postId, currentUserId(authentication));
    }
}
