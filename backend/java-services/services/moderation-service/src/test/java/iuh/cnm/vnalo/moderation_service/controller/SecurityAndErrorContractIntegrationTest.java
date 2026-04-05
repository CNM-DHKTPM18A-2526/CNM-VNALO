package iuh.cnm.vnalo.moderation_service.controller;

import iuh.cnm.vnalo.moderation_service.exception.ApiException;
import iuh.cnm.vnalo.moderation_service.exception.ErrorCode;
import iuh.cnm.vnalo.moderation_service.security.ModeratorGuardService;
import iuh.cnm.vnalo.moderation_service.service.AdminUserService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.util.UUID;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doNothing;
import static org.mockito.Mockito.doThrow;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class SecurityAndErrorContractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private ModeratorGuardService moderatorGuardService;

    @MockBean
    private AdminUserService adminUserService;

    @Test
    void moderationEndpoint_shouldReturn401_whenUnauthenticated() throws Exception {
        mockMvc.perform(get("/api/v1/moderation/reports"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.code").value(401))
                .andExpect(jsonPath("$.errorCode").value("ERR_401"));
    }

    @Test
    @WithMockUser(username = "11111111-1111-1111-1111-111111111111", roles = {"USER"})
    void moderationEndpoint_shouldReturn403_forUserRole() throws Exception {
        doThrow(new ApiException(ErrorCode.MODERATION_FORBIDDEN))
                .when(moderatorGuardService).requireModerator(any(UUID.class));

        mockMvc.perform(get("/api/v1/moderation/reports"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.code").value(403))
                .andExpect(jsonPath("$.errorCode").value("MOD_010"));
    }

    @Test
    @WithMockUser(username = "22222222-2222-2222-2222-222222222222", roles = {"MODERATOR"})
    void adminEndpoint_shouldReturn403_forModeratorRole() throws Exception {
        doThrow(new ApiException(ErrorCode.MODERATION_FORBIDDEN))
                .when(moderatorGuardService).requireAdmin(any(UUID.class));

        mockMvc.perform(post("/api/v1/admin/users")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"userId\":\"33333333-3333-3333-3333-333333333333\",\"role\":\"MODERATOR\"}"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.code").value(403))
                .andExpect(jsonPath("$.errorCode").value("MOD_010"));
    }

    @Test
    @WithMockUser(username = "44444444-4444-4444-4444-444444444444", roles = {"ADMIN"})
    void adminCreate_shouldReturn400_withValidationErrorContract() throws Exception {
        mockMvc.perform(post("/api/v1/admin/users")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.code").value(400))
                .andExpect(jsonPath("$.errorCode").value("ERR_400"))
                .andExpect(jsonPath("$.details.userId").exists())
                .andExpect(jsonPath("$.details.role").exists());
    }

    @Test
    @WithMockUser(username = "55555555-5555-5555-5555-555555555555", roles = {"ADMIN"})
    void adminCreate_shouldReturn405_withStandardContract() throws Exception {
        mockMvc.perform(put("/api/v1/admin/users")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isMethodNotAllowed())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.code").value(405))
                .andExpect(jsonPath("$.errorCode").value("ERR_405"));
    }

    @Test
    @WithMockUser(username = "66666666-6666-6666-6666-666666666666", roles = {"ADMIN"})
    void unknownEndpoint_shouldReturn404_withStandardContract() throws Exception {
        mockMvc.perform(get("/api/v1/moderation/not-found-endpoint"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.code").value(404))
                .andExpect(jsonPath("$.errorCode").value("ERR_404"));
    }

    // ADMIN Role Authorization Tests
    @Test
    @WithMockUser(username = "77777777-7777-7777-7777-777777777777", roles = {"ADMIN"})
    void adminAccessingModerationEndpoint_shouldReturn200_whenGuardPasses() throws Exception {
        doNothing().when(moderatorGuardService).requireModerator(any(UUID.class));

        mockMvc.perform(get("/api/v1/moderation/reports"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true));
    }

    @Test
    @WithMockUser(username = "88888888-8888-8888-8888-888888888888", roles = {"ADMIN"})
    void adminAccessingAdminEndpoint_shouldReturn200_whenGuardAndValidationPass() throws Exception {
        doNothing().when(moderatorGuardService).requireAdmin(any(UUID.class));

        UUID validAdminId = UUID.fromString("88888888-8888-8888-8888-888888888888");
        String request = "{\"userId\":\"99999999-9999-9999-9999-999999999999\",\"role\":\"MODERATOR\"}";

        mockMvc.perform(post("/api/v1/admin/users")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(request))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true));
    }

    // Moderation Admin User Enforcement Tests
    @Test
    @WithMockUser(username = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", roles = {"ADMIN"})
    void adminAccessingAdminEndpoint_shouldReturn403_whenNotInModerationAdminUserTable() throws Exception {
        doThrow(new ApiException(ErrorCode.MODERATION_FORBIDDEN))
                .when(moderatorGuardService).requireAdmin(any(UUID.class));

        String request = "{\"userId\":\"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb\",\"role\":\"MODERATOR\"}";

        mockMvc.perform(post("/api/v1/admin/users")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(request))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.code").value(403))
                .andExpect(jsonPath("$.errorCode").value("MOD_010"));
    }

    @Test
    @WithMockUser(username = "cccccccc-cccc-cccc-cccc-cccccccccccc", roles = {"ADMIN"})
    void adminAccessingModerationEndpoint_shouldReturn403_whenNotInModerationAdminUserTable() throws Exception {
        doThrow(new ApiException(ErrorCode.MODERATION_FORBIDDEN))
                .when(moderatorGuardService).requireModerator(any(UUID.class));

        mockMvc.perform(get("/api/v1/moderation/reports"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.code").value(403))
                .andExpect(jsonPath("$.errorCode").value("MOD_010"));
    }

    // is_active=false Enforcement Tests
    @Test
    @WithMockUser(username = "dddddddd-dddd-dddd-dddd-dddddddddddd", roles = {"ADMIN"})
    void adminWithInactiveStatus_shouldReturn403_whenAccessingAdminEndpoint() throws Exception {
        doThrow(new ApiException(ErrorCode.MODERATION_FORBIDDEN))
                .when(moderatorGuardService).requireAdmin(any(UUID.class));

        String request = "{\"userId\":\"eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee\",\"role\":\"MODERATOR\"}";

        mockMvc.perform(post("/api/v1/admin/users")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(request))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.code").value(403))
                .andExpect(jsonPath("$.errorCode").value("MOD_010"));
    }

    @Test
    @WithMockUser(username = "ffffffff-ffff-ffff-ffff-ffffffffffff", roles = {"MODERATOR"})
    void moderatorWithInactiveStatus_shouldReturn403_whenAccessingModerationEndpoint() throws Exception {
        doThrow(new ApiException(ErrorCode.MODERATION_FORBIDDEN))
                .when(moderatorGuardService).requireModerator(any(UUID.class));

        mockMvc.perform(get("/api/v1/moderation/reports"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.code").value(403))
                .andExpect(jsonPath("$.errorCode").value("MOD_010"));
    }

    // 500 Error Handling Test
    @Test
    @WithMockUser(username = "10101010-1010-1010-1010-101010101010", roles = {"ADMIN"})
    void internalServerError_shouldReturn500_withoutExposingStackTrace() throws Exception {
        doNothing().when(moderatorGuardService).requireAdmin(any(UUID.class));
        doThrow(new RuntimeException("Simulated internal server error"))
                .when(adminUserService).createAdminUser(any());

        String request = "{\"userId\":\"11111111-1111-1111-1111-111111111111\",\"role\":\"MODERATOR\"}";

        mockMvc.perform(post("/api/v1/admin/users")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(request))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.code").value(500))
                .andExpect(jsonPath("$.errorCode").value("ERR_500"))
                .andExpect(jsonPath("$.message").value("An unexpected error occurred"))
                .andExpect(jsonPath("$.details").doesNotExist());
    }
}
