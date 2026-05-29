package iuh.cnm.vnalo.content_service.controller;

import iuh.cnm.vnalo.content_service.model.dto.CommentPageResponse;
import iuh.cnm.vnalo.content_service.model.dto.CommentResponse;
import iuh.cnm.vnalo.content_service.model.dto.CreateCommentRequest;
import iuh.cnm.vnalo.content_service.model.dto.UpdateCommentRequest;
import iuh.cnm.vnalo.content_service.service.CommentService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequiredArgsConstructor
public class CommentController {

    private final CommentService commentService;
    
    private UUID currentUserId(Authentication authentication) {
        return UUID.fromString(authentication.getName());
    }

    @PostMapping("/posts/{postId}/comments")
    @ResponseStatus(HttpStatus.CREATED)
    public CommentResponse createComment(
            @PathVariable UUID postId,
            Authentication authentication,
            @Valid @RequestBody CreateCommentRequest request
    ) {
        return commentService.createComment(postId, currentUserId(authentication), request);
    }

    @GetMapping("/posts/{postId}/comments")
    public CommentPageResponse getComments(
            @PathVariable UUID postId,
            Authentication authentication,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        return commentService.getCommentsByPost(postId, currentUserId(authentication), page, size);
    }

    @PutMapping("/comments/{commentId}")
    public CommentResponse updateComment(
            @PathVariable UUID commentId,
            Authentication authentication,
            @Valid @RequestBody UpdateCommentRequest request
    ) {
        return commentService.updateComment(commentId, currentUserId(authentication), request);
    }

    @DeleteMapping("/comments/{commentId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteComment(
            @PathVariable UUID commentId,
            Authentication authentication
    ) {
        commentService.deleteComment(commentId, currentUserId(authentication));
    }
}