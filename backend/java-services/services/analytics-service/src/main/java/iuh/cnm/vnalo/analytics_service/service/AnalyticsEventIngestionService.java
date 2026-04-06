package iuh.cnm.vnalo.analytics_service.service;

import iuh.cnm.vnalo.analytics_service.model.dto.request.AnalyticsEventRequest;
import iuh.cnm.vnalo.analytics_service.model.entity.AnalyticsEvent;
import iuh.cnm.vnalo.analytics_service.repository.AnalyticsEventRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AnalyticsEventIngestionService {
    private final AnalyticsEventRepository analyticsEventRepository;

    @Transactional
    public UUID ingestEvent(AnalyticsEventRequest request) {
        AnalyticsEvent event = analyticsEventRepository.save(
                AnalyticsEvent.builder()
                        .eventType(request.getEventType())
                        .actorUserId(request.getActorUserId())
                        .targetType(request.getTargetType())
                        .targetId(request.getTargetId())
                        .sourceService(request.getSourceService())
                        .occurredAt(request.getOccurredAt())
                        .payloadJson(request.getPayloadJson())
                        .build()
        );
        return event.getId();
    }
}