package iuh.cnm.vnalo.core_service.service;

import iuh.cnm.vnalo.core_service.model.dto.response.SessionAuditResponse;
import iuh.cnm.vnalo.core_service.model.entity.auth.AuthRefreshToken;
import iuh.cnm.vnalo.core_service.model.entity.auth.AuthSessionAudit;
import iuh.cnm.vnalo.core_service.repository.auth.AuthSessionAuditRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class SessionAuditService {

    private final AuthSessionAuditRepository authSessionAuditRepository;

    @Transactional
    public void record(
            UUID accountId,
            AuthRefreshToken token,
            String eventType,
            String sessionType,
            String trustLevel,
            String detail
    ) {
        final AuthSessionAudit audit = AuthSessionAudit.builder()
                .accountId(accountId)
                .tokenId(token != null ? token.getTokenId() : null)
                .eventType(eventType)
                .sessionType(sessionType)
                .trustLevel(trustLevel)
                .platform(token != null ? token.getPlatform() : null)
                .deviceId(token != null ? token.getDeviceId() : null)
                .deviceName(token != null ? token.getDeviceName() : null)
                .ipAddress(token != null ? token.getIpAddress() : null)
                .detail(detail)
                .build();
        authSessionAuditRepository.save(audit);
    }

    @Transactional(readOnly = true)
    public List<SessionAuditResponse> getAudits(UUID accountId, int limit) {
        final int pageSize = Math.max(1, Math.min(limit, 100));
        return authSessionAuditRepository
                .findByAccountIdOrderByCreatedAtDesc(accountId, PageRequest.of(0, pageSize))
                .stream()
                .map(a -> new SessionAuditResponse(
                        a.getAuditId(),
                        a.getTokenId(),
                        a.getEventType(),
                        a.getSessionType(),
                        a.getTrustLevel(),
                        a.getPlatform(),
                        a.getDeviceId(),
                        a.getDeviceName(),
                        a.getIpAddress(),
                        a.getDetail(),
                        a.getCreatedAt()
                ))
                .toList();
    }
}
