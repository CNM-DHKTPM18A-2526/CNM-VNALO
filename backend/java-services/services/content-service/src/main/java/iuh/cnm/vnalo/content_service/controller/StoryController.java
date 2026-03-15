package iuh.cnm.vnalo.content_service.controller;

import iuh.cnm.vnalo.content_service.model.dto.CreateStoryRequest;
import iuh.cnm.vnalo.content_service.model.dto.StoryResponse;
import iuh.cnm.vnalo.content_service.service.StoryService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/stories")
@RequiredArgsConstructor
public class StoryController {

    private final StoryService storyService;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public StoryResponse createStory(
            @RequestHeader("X-User-Id") UUID userId,
            @Valid @RequestBody CreateStoryRequest request
    ) {
        return storyService.createStory(userId, request);
    }

    @GetMapping
    public List<StoryResponse> getStories() {
        return storyService.getActiveStories();
    }

    @DeleteMapping("/{storyId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteStory(
            @PathVariable UUID storyId,
            @RequestHeader("X-User-Id") UUID userId
    ) {
        storyService.deleteStory(storyId, userId);
    }
}