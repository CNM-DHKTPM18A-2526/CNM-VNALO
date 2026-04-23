package iuh.cnm.vnalo.content_service.controller;

import iuh.cnm.vnalo.content_service.model.dto.CreateStoryRequest;
import iuh.cnm.vnalo.content_service.model.dto.StoryResponse;
import iuh.cnm.vnalo.content_service.model.dto.StoryViewResponse;
import iuh.cnm.vnalo.content_service.service.StoryService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/stories")
@RequiredArgsConstructor
public class StoryController {

    private final StoryService storyService;
    
    private UUID currentUserId(Authentication authentication) {
        return UUID.fromString(authentication.getName());
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public StoryResponse createStory(
            Authentication authentication,
            @Valid @RequestBody CreateStoryRequest request
    ) {
        return storyService.createStory(currentUserId(authentication), request);
    }

    @GetMapping
    public List<StoryResponse> getStories() {
        return storyService.getActiveStories();
    }

    @DeleteMapping("/{storyId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteStory(
            @PathVariable UUID storyId,
            Authentication authentication
    ) {
        storyService.deleteStory(storyId, currentUserId(authentication));
    }

    @PostMapping("/{storyId}/view")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void markViewed(
            @PathVariable UUID storyId,
            Authentication authentication
    ) {
        storyService.markViewed(storyId, currentUserId(authentication));
    }

    @GetMapping("/{storyId}/views")
    public List<StoryViewResponse> getStoryViews(@PathVariable UUID storyId) {
        return storyService.getStoryViews(storyId);
    }
}