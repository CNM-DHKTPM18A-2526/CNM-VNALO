package iuh.cnm.vnalo.moderation_service.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import iuh.cnm.vnalo.moderation_service.model.dto.request.CreateAppealRequest;
import iuh.cnm.vnalo.moderation_service.model.dto.request.ResolveAppealRequest;
import iuh.cnm.vnalo.moderation_service.model.entity.ModerationAppeal;
import iuh.cnm.vnalo.moderation_service.model.enums.AppealStatus;
import iuh.cnm.vnalo.moderation_service.repository.ModerationAppealRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AppealServiceTest {

    @Mock
    private ModerationAppealRepository appealRepository;

    @Mock
    private AuditLogService auditLogService;

    @InjectMocks
    private AppealService appealService;

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Test
    void createAppeal_shouldLogJsonPayload() throws Exception {
        UUID appealId = UUID.randomUUID();
        UUID caseId = UUID.randomUUID();
        UUID userId = UUID.randomUUID();

        ModerationAppeal saved = ModerationAppeal.builder()
                .id(appealId)
                .caseId(caseId)
                .userId(userId)
                .reason("Please review")
                .status(AppealStatus.PENDING)
                .build();

        when(appealRepository.save(any(ModerationAppeal.class))).thenReturn(saved);

        CreateAppealRequest request = CreateAppealRequest.builder().reason("Please review").build();
        appealService.createAppeal(userId, caseId, request);

        ArgumentCaptor<String> newValueCaptor = ArgumentCaptor.forClass(String.class);
        verify(auditLogService).log(any(), any(), any(), any(), newValueCaptor.capture(), any());

        String newValueJson = newValueCaptor.getValue();
        assertThat(objectMapper.readTree(newValueJson).get("appealId").asText()).isEqualTo(appealId.toString());
        assertThat(objectMapper.readTree(newValueJson).get("caseId").asText()).isEqualTo(caseId.toString());
        assertThat(objectMapper.readTree(newValueJson).get("status").asText()).isEqualTo("PENDING");
    }

    @Test
    void resolveAppeal_shouldLogJsonPayload() throws Exception {
        UUID appealId = UUID.randomUUID();
        UUID caseId = UUID.randomUUID();
        UUID userId = UUID.randomUUID();

        ModerationAppeal existing = ModerationAppeal.builder()
                .id(appealId)
                .caseId(caseId)
                .userId(userId)
                .reason("Please review")
                .status(AppealStatus.PENDING)
                .build();

        when(appealRepository.findById(appealId)).thenReturn(Optional.of(existing));
        when(appealRepository.save(any(ModerationAppeal.class))).thenReturn(existing);

        ResolveAppealRequest request = ResolveAppealRequest.builder()
                .status(AppealStatus.APPROVED)
                .response("Accepted")
                .build();

        appealService.resolveAppeal(appealId, request, userId);

        ArgumentCaptor<String> newValueCaptor = ArgumentCaptor.forClass(String.class);
        verify(auditLogService).log(any(), any(), any(), any(), newValueCaptor.capture(), any());

        String newValueJson = newValueCaptor.getValue();
        assertThat(objectMapper.readTree(newValueJson).get("appealId").asText()).isEqualTo(appealId.toString());
        assertThat(objectMapper.readTree(newValueJson).get("status").asText()).isEqualTo("APPROVED");
    }
}
