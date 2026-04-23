package iuh.cnm.vnalo.content_service.controller;

import iuh.cnm.vnalo.content_service.model.dto.CreatePostRequest;
import iuh.cnm.vnalo.content_service.model.dto.PostResponse;
import iuh.cnm.vnalo.content_service.model.dto.TimelineResponse;
import iuh.cnm.vnalo.content_service.model.dto.UpdatePostRequest;
import iuh.cnm.vnalo.content_service.service.PostService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/posts")
@RequiredArgsConstructor
public class PostController {

    private final PostService postService;
    
    private UUID currentUserId(Authentication authentication) {
        return UUID.fromString(authentication.getName());
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public PostResponse createPost(
            Authentication authentication,
            @Valid @RequestBody CreatePostRequest request
    ) {
        return postService.createPost(currentUserId(authentication), request);
    }

    @GetMapping("/timeline")
    public TimelineResponse getTimeline(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        return postService.getTimeline(page, size);
    }

    @GetMapping("/{postId}")
    public PostResponse getPostById(@PathVariable UUID postId) {
        return postService.getPostById(postId);
    }

    @PutMapping("/{postId}")
    public PostResponse updatePost(
            @PathVariable UUID postId,
            Authentication authentication,
            @Valid @RequestBody UpdatePostRequest request
    ) {
        return postService.updatePost(postId, currentUserId(authentication), request);
    }

    @DeleteMapping("/{postId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deletePost(
            @PathVariable UUID postId,
            Authentication authentication
    ) {
        postService.deletePost(postId, currentUserId(authentication));
    }
}