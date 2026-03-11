package iuh.cnm.vnalo.content_service.controller;

import iuh.cnm.vnalo.content_service.model.dto.CommentPageResponse;
import iuh.cnm.vnalo.content_service.model.dto.CommentResponse;
import iuh.cnm.vnalo.content_service.model.dto.CreateCommentRequest;
import iuh.cnm.vnalo.content_service.service.CommentService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/posts/{postId}/comments")
@RequiredArgsConstructor
public class CommentController {

    private final CommentService commentService;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public CommentResponse createComment(
            @PathVariable UUID postId,
            @RequestHeader("X-User-Id") UUID userId,
            @Valid @RequestBody CreateCommentRequest request
    ) {
        return commentService.createComment(postId, userId, request);
    }

    @GetMapping
    public CommentPageResponse getComments(
            @PathVariable UUID postId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        return commentService.getCommentsByPost(postId, page, size);
    }
}