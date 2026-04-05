package iuh.cnm.vnalo.content_service.controller;

import iuh.cnm.vnalo.content_service.service.LikeService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/posts/{postId}/like")
@RequiredArgsConstructor
public class LikeController {

    private final LikeService likeService;

    @PostMapping
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void likePost(
            @PathVariable UUID postId,
            @RequestHeader("X-User-Id") UUID userId
    ) {
        likeService.likePost(postId, userId);
    }

    @DeleteMapping
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unlikePost(
            @PathVariable UUID postId,
            @RequestHeader("X-User-Id") UUID userId
    ) {
        likeService.unlikePost(postId, userId);
    }
}