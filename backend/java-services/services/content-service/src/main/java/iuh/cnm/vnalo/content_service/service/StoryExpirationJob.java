package iuh.cnm.vnalo.content_service.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class StoryExpirationJob {

    private final StoryService storyService;

    @Scheduled(fixedRate = 600000)
    public void expireStories() {
        int count = storyService.expireStories();
        if (count > 0) {
            log.info("Expired {} stories", count);
        }
    }
}