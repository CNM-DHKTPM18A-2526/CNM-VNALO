package iuh.cnm.vnalo.content_service.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import java.util.HashSet;
import java.util.Set;
import java.util.UUID;

/**
 * Loads friend IDs from core-service (vnalo.fit) using the caller's JWT.
 * Used when content-service runs locally but users authenticate on production.
 */
@Component
@Slf4j
public class CoreFriendshipClient {

    private final ObjectMapper objectMapper;
    private final RestClient restClient;
    private final boolean enabled;

    public CoreFriendshipClient(
            ObjectMapper objectMapper,
            @Value("${app.core-service.base-url:}") String baseUrl
    ) {
        this.objectMapper = objectMapper;
        String normalizedBaseUrl = String.valueOf(baseUrl).trim();
        if (normalizedBaseUrl.endsWith("/")) {
            normalizedBaseUrl = normalizedBaseUrl.substring(0, normalizedBaseUrl.length() - 1);
        }
        this.enabled = StringUtils.hasText(normalizedBaseUrl);
        this.restClient = enabled
                ? RestClient.builder().baseUrl(normalizedBaseUrl).build()
                : null;
    }

    public boolean isEnabled() {
        return enabled;
    }

    public Set<UUID> fetchFriendIds(String authorizationHeader) {
        if (!enabled || !StringUtils.hasText(authorizationHeader)) {
            return Set.of();
        }

        Set<UUID> friendIds = new HashSet<>();
        int page = 0;
        final int pageSize = 200;

        try {
            while (true) {
                final int currentPage = page;
                String body = restClient.get()
                        .uri(uriBuilder -> uriBuilder
                                .path("/friends")
                                .queryParam("page", currentPage)
                                .queryParam("size", pageSize)
                                .build())
                        .header(HttpHeaders.AUTHORIZATION, authorizationHeader)
                        .retrieve()
                        .body(String.class);

                if (!StringUtils.hasText(body)) {
                    break;
                }

                JsonNode root = objectMapper.readTree(body);
                JsonNode pageNode = root.path("data");
                JsonNode content = pageNode.path("content");
                if (!content.isArray() || content.isEmpty()) {
                    break;
                }

                for (JsonNode item : content) {
                    String friendId = item.path("friendId").asText(null);
                    if (StringUtils.hasText(friendId)) {
                        friendIds.add(UUID.fromString(friendId));
                    }
                }

                boolean last = pageNode.path("last").asBoolean(true);
                if (last) {
                    break;
                }
                page++;
            }
        } catch (RestClientException | IllegalArgumentException ex) {
            log.warn("Failed to load friends from core-service: {}", ex.getMessage());
            return Set.of();
        } catch (Exception ex) {
            log.warn("Unexpected error while loading friends from core-service", ex);
            return Set.of();
        }

        return friendIds;
    }
}
