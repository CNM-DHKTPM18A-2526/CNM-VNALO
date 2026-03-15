package iuh.cnm.vnalo.content_service.service;

import iuh.cnm.vnalo.content_service.repository.StoryRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class StoryExpirationJob {

    private final StoryRepository storyRepository;

    @Scheduled(fixedRate = 600000)
    public void cleanupExpiredStories() {

        log.info("Checking expired stories...");

        // có thể update status expired
    }
}