package iuh.cnm.vnalo.analytics_service.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import iuh.cnm.vnalo.analytics_service.model.dto.request.ClientAnalyticsEventRequest;
import iuh.cnm.vnalo.analytics_service.model.dto.response.BehavioralAnalyticsSummaryResponse;
import iuh.cnm.vnalo.analytics_service.model.dto.response.EventCountResponse;
import iuh.cnm.vnalo.analytics_service.model.entity.AnalyticsEvent;
import iuh.cnm.vnalo.analytics_service.model.enums.AnalyticsEventType;
import iuh.cnm.vnalo.analytics_service.repository.AnalyticsEventRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneOffset;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class BehavioralAnalyticsService {
    private static final int MAX_METADATA_FIELDS = 24;
    private static final int MAX_STRING_LENGTH = 180;
    private static final long MAX_EVENT_CLOCK_SKEW_SECONDS = 300;
    private static final Set<String> SENSITIVE_KEYS = Set.of(
            "password", "otp", "token", "accessToken", "refreshToken", "authorization", "secret",
            "apiKey", "prompt", "message", "content", "text", "raw", "image", "embedding", "faceImage"
    );

    private final AnalyticsEventRepository analyticsEventRepository;
    private final ObjectMapper objectMapper;

    public UUID ingestClientEvent(UUID actorUserId, ClientAnalyticsEventRequest request) {
        Instant occurredAt = normalizeOccurredAt(request.getOccurredAt());
        Map<String, Object> payload = new LinkedHashMap<>();
        putIfPresent(payload, "sessionId", sanitizeString(request.getSessionId(), 64));
        putIfPresent(payload, "platform", sanitizeString(request.getPlatform(), 32));
        putIfPresent(payload, "screenName", sanitizeString(request.getScreenName(), 120));
        putIfPresent(payload, "featureName", sanitizeString(request.getFeatureName(), 120));
        if (request.getDurationMs() != null && request.getDurationMs() >= 0 && request.getDurationMs() <= 86_400_000L) {
            payload.put("durationMs", request.getDurationMs());
        }
        putIfPresent(payload, "appVersion", sanitizeString(request.getAppVersion(), 40));
        putIfPresent(payload, "locale", sanitizeString(request.getLocale(), 40));
        putIfPresent(payload, "timezone", sanitizeString(request.getTimezone(), 24));
        payload.put("metadata", sanitizeMetadata(request.getMetadata()));

        AnalyticsEvent event = analyticsEventRepository.save(AnalyticsEvent.builder()
                .eventType(request.getEventType())
                .actorUserId(actorUserId)
                .targetType(resolveTargetType(request.getEventType()))
                .sourceService("web-client")
                .occurredAt(occurredAt)
                .payloadJson(writePayload(payload))
                .build());
        return event.getId();
    }

    public BehavioralAnalyticsSummaryResponse getSummary(LocalDate from, LocalDate to) {
        Instant fromInstant = from.atStartOfDay().toInstant(ZoneOffset.UTC);
        Instant toInstant = to.atTime(LocalTime.MAX).toInstant(ZoneOffset.UTC);
        List<AnalyticsEvent> events = analyticsEventRepository.findTop5000ByOccurredAtBetweenOrderByOccurredAtDesc(fromInstant, toInstant);

        return BehavioralAnalyticsSummaryResponse.builder()
                .eventsTotal(analyticsEventRepository.countByOccurredAtBetween(fromInstant, toInstant))
                .activeUsers(analyticsEventRepository.countDistinctActorsBetween(fromInstant, toInstant))
                .sessionsStarted(count(AnalyticsEventType.APP_SESSION_STARTED, fromInstant, toInstant))
                .sessionsEnded(count(AnalyticsEventType.APP_SESSION_ENDED, fromInstant, toInstant))
                .screenViews(count(AnalyticsEventType.SCREEN_VIEWED, fromInstant, toInstant))
                .featureUses(count(AnalyticsEventType.FEATURE_USED, fromInstant, toInstant))
                .clientErrors(count(AnalyticsEventType.CLIENT_ERROR, fromInstant, toInstant))
                .apiErrors(count(AnalyticsEventType.API_ERROR, fromInstant, toInstant))
                .aiPrompts(count(AnalyticsEventType.AI_PROMPT_SENT, fromInstant, toInstant))
                .aiFailures(count(AnalyticsEventType.AI_RESPONSE_FAILED, fromInstant, toInstant))
                .faceAuthAttempts(count(AnalyticsEventType.FACE_ENROLL_STARTED, fromInstant, toInstant)
                        + count(AnalyticsEventType.FACE_VERIFY_SUCCEEDED, fromInstant, toInstant)
                        + count(AnalyticsEventType.FACE_VERIFY_FAILED, fromInstant, toInstant))
                .averageSessionDurationMinutes(averageSessionDurationMinutes(events))
                .topEvents(topByEventType(events))
                .topScreens(topByPayloadKey(events, "screenName"))
                .topFeatures(topByPayloadKey(events, "featureName"))
                .hourlyUsage(topByHour(events))
                .build();
    }

    private long count(AnalyticsEventType type, Instant from, Instant to) {
        return analyticsEventRepository.countByEventTypeAndOccurredAtBetween(type, from, to);
    }

    private Instant normalizeOccurredAt(Instant occurredAt) {
        Instant now = Instant.now();
        if (occurredAt == null) return now;
        if (occurredAt.isAfter(now.plusSeconds(MAX_EVENT_CLOCK_SKEW_SECONDS))) return now;
        return occurredAt;
    }

    private String resolveTargetType(AnalyticsEventType eventType) {
        return switch (eventType) {
            case SCREEN_VIEWED -> "SCREEN";
            case FEATURE_USED -> "FEATURE";
            case AI_PANEL_OPENED, AI_PROMPT_SENT, AI_RESPONSE_RECEIVED, AI_RESPONSE_FAILED, AI_IMAGE_ANALYSIS_USED -> "AI";
            case FACE_ENROLL_STARTED, FACE_VERIFY_SUCCEEDED, FACE_VERIFY_FAILED, FACE_MODEL_UNAVAILABLE -> "FACE_AUTH";
            case API_ERROR, CLIENT_ERROR -> "ERROR";
            default -> "SESSION";
        };
    }

    private Map<String, Object> sanitizeMetadata(Map<String, Object> metadata) {
        if (metadata == null || metadata.isEmpty()) return Map.of();
        Map<String, Object> safe = new LinkedHashMap<>();
        for (Map.Entry<String, Object> entry : metadata.entrySet()) {
            if (safe.size() >= MAX_METADATA_FIELDS) break;
            String key = sanitizeString(entry.getKey(), 64);
            if (!StringUtils.hasText(key) || isSensitiveKey(key)) continue;
            Object value = entry.getValue();
            if (value instanceof Number || value instanceof Boolean) {
                safe.put(key, value);
            } else if (value instanceof String stringValue) {
                safe.put(key, sanitizeString(stringValue, MAX_STRING_LENGTH));
            }
        }
        return safe;
    }

    private boolean isSensitiveKey(String key) {
        String normalized = key.toLowerCase(Locale.ROOT);
        return SENSITIVE_KEYS.stream().anyMatch(normalized::contains);
    }

    private String sanitizeString(String value, int maxLength) {
        if (!StringUtils.hasText(value)) return null;
        String normalized = value.trim().replaceAll("[\\r\\n\\t]+", " ");
        if (normalized.length() > maxLength) return normalized.substring(0, maxLength);
        return normalized;
    }

    private void putIfPresent(Map<String, Object> payload, String key, String value) {
        if (StringUtils.hasText(value)) payload.put(key, value);
    }

    private String writePayload(Map<String, Object> payload) {
        try {
            return objectMapper.writeValueAsString(payload);
        } catch (JsonProcessingException e) {
            return "{}";
        }
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> readPayload(AnalyticsEvent event) {
        if (!StringUtils.hasText(event.getPayloadJson())) return Map.of();
        try {
            return objectMapper.readValue(event.getPayloadJson(), Map.class);
        } catch (Exception ignored) {
            return Map.of();
        }
    }

    private double averageSessionDurationMinutes(List<AnalyticsEvent> events) {
        List<Long> durations = events.stream()
                .filter(event -> event.getEventType() == AnalyticsEventType.APP_SESSION_ENDED)
                .map(this::readPayload)
                .map(payload -> payload.get("durationMs"))
                .filter(Number.class::isInstance)
                .map(Number.class::cast)
                .map(Number::longValue)
                .filter(value -> value > 0)
                .toList();
        if (durations.isEmpty()) return 0;
        double avgMs = durations.stream().mapToLong(Long::longValue).average().orElse(0);
        return Math.round((avgMs / 60000.0) * 10.0) / 10.0;
    }

    private List<EventCountResponse> topByEventType(List<AnalyticsEvent> events) {
        return events.stream()
                .collect(Collectors.groupingBy(event -> event.getEventType().name(), Collectors.counting()))
                .entrySet().stream()
                .sorted(Map.Entry.<String, Long>comparingByValue(Comparator.reverseOrder()))
                .limit(8)
                .map(entry -> new EventCountResponse(entry.getKey(), entry.getValue()))
                .toList();
    }

    private List<EventCountResponse> topByPayloadKey(List<AnalyticsEvent> events, String key) {
        Map<String, Long> counts = new HashMap<>();
        for (AnalyticsEvent event : events) {
            Object value = readPayload(event).get(key);
            if (value instanceof String text && StringUtils.hasText(text)) {
                counts.merge(text, 1L, Long::sum);
            }
        }
        return counts.entrySet().stream()
                .sorted(Map.Entry.<String, Long>comparingByValue(Comparator.reverseOrder()))
                .limit(8)
                .map(entry -> new EventCountResponse(entry.getKey(), entry.getValue()))
                .toList();
    }

    private List<EventCountResponse> topByHour(List<AnalyticsEvent> events) {
        return events.stream()
                .collect(Collectors.groupingBy(event -> String.format("%02d:00", event.getOccurredAt().atOffset(ZoneOffset.UTC).getHour()), Collectors.counting()))
                .entrySet().stream()
                .sorted(Map.Entry.comparingByKey())
                .map(entry -> new EventCountResponse(entry.getKey(), entry.getValue()))
                .toList();
    }
}
