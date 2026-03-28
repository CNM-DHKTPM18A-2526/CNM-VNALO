package iuh.cnm.vnalo.moderation_service.controller;

import iuh.cnm.vnalo.moderation_service.dto.ReportDTO;
import iuh.cnm.vnalo.moderation_service.model.dto.request.CreateAdminUserRequest;
import iuh.cnm.vnalo.moderation_service.model.dto.response.ApiResponse;
import iuh.cnm.vnalo.moderation_service.model.enums.ModerationAdminRole;
import iuh.cnm.vnalo.moderation_service.security.ModeratorGuardService;
import iuh.cnm.vnalo.moderation_service.service.AdminUserService;
import iuh.cnm.vnalo.moderation_service.service.AppealService;
import iuh.cnm.vnalo.moderation_service.service.ModerationActionService;
import iuh.cnm.vnalo.moderation_service.service.ModerationCaseService;
import iuh.cnm.vnalo.moderation_service.service.ReportService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.security.core.Authentication;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ControllerAuthenticationRegressionTest {

    @Mock
    private ModeratorGuardService moderatorGuardService;

    @Mock
    private AdminUserService adminUserService;

    @Mock
    private ReportService reportService;

    @Mock
    private ModerationCaseService moderationCaseService;

    @Mock
    private ModerationActionService moderationActionService;

    @Mock
    private AppealService appealService;

    @Mock
    private Authentication authentication;

    @InjectMocks
    private AdminUserController adminUserController;

    @InjectMocks
    private ModerationController moderationController;

    @Test
    void createAdminUser_shouldAcceptStringPrincipalId() {
        UUID currentUserId = UUID.randomUUID();
        UUID targetUserId = UUID.randomUUID();

        when(authentication.getPrincipal()).thenReturn(currentUserId.toString());

        CreateAdminUserRequest request = new CreateAdminUserRequest();
        request.setUserId(targetUserId);
        request.setRole(ModerationAdminRole.MODERATOR);

        ApiResponse<Void> response = adminUserController.createAdminUser(authentication, request);

        assertThat(response.isSuccess()).isTrue();
        verify(moderatorGuardService).requireAdmin(currentUserId);
        verify(adminUserService).createAdminUser(request);
    }

    @Test
    void getReports_shouldAcceptStringPrincipalId() {
        UUID currentUserId = UUID.randomUUID();
        when(authentication.getPrincipal()).thenReturn(currentUserId.toString());
        when(reportService.getReports(any(), any())).thenReturn(Page.<ReportDTO>empty());

        ApiResponse<Page<ReportDTO>> response = moderationController.getReports(authentication, null, null, 0, 20);

        assertThat(response.isSuccess()).isTrue();
        verify(moderatorGuardService).requireModerator(currentUserId);
        verify(reportService).getReports(any(), any());
    }
}
