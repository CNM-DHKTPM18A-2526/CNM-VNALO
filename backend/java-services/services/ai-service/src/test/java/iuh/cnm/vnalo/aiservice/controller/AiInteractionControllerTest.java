package iuh.cnm.vnalo.aiservice.controller;

import iuh.cnm.vnalo.aiservice.dto.ApiResponse;
import iuh.cnm.vnalo.aiservice.dto.request.AiChatRequest;
import iuh.cnm.vnalo.aiservice.dto.response.AiChatResponse;
import iuh.cnm.vnalo.aiservice.service.ChatService;
import iuh.cnm.vnalo.aiservice.service.GeminiAiService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.InsufficientAuthenticationException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AiInteractionControllerTest {

    @Mock
    private GeminiAiService geminiAiService;

    @Mock
    private ChatService chatService;

    @AfterEach
    void clearContext() {
        SecurityContextHolder.clearContext();
    }

    private void authenticateTestUser() {
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken("user-1", null, java.util.Collections.emptyList())
        );
    }

    @Test
    void interactWithMascot_shouldReturnGracefulFallbackWhenProvidersFail() {
        authenticateTestUser();
        AiInteractionController controller = new AiInteractionController(geminiAiService, chatService);
        AiChatRequest request = AiChatRequest.builder()
                .prompt("hello")
                .analyzeIntent(true)
                .build();
        when(geminiAiService.interactWithGemini(eq("user-1"), any(AiChatRequest.class)))
                .thenThrow(new RuntimeException("AI_SERVICE_ERROR"));

        ResponseEntity<?> entity = controller.interactWithMascot(request);

        assertEquals(200, entity.getStatusCode().value());
        ApiResponse<?> body = (ApiResponse<?>) entity.getBody();
        assertNotNull(body);
        assertTrue(body.isSuccess());
        AiChatResponse data = (AiChatResponse) body.getData();
        assertNotNull(data);
        assertNull(data.getActionCommand());
        assertTrue(data.getTextReply().contains("AI"));
        assertTrue(data.isDegraded());
        assertEquals("AI_PROVIDER_UNAVAILABLE", data.getProviderStatus());
    }

    @Test
    void interactWithMascot_shouldRequireAuthenticatedUserBeforeFallback() {
        AiInteractionController controller = new AiInteractionController(geminiAiService, chatService);
        AiChatRequest request = AiChatRequest.builder()
                .prompt("hello")
                .analyzeIntent(true)
                .build();

        assertThrows(InsufficientAuthenticationException.class, () -> controller.interactWithMascot(request));
    }

    @Test
    void interactWithMascot_shouldNotEmitCallCommandWithoutClearTargetWhenProvidersFail() {
        authenticateTestUser();
        AiInteractionController controller = new AiInteractionController(geminiAiService, chatService);
        AiChatRequest request = AiChatRequest.builder()
                .prompt("call video for this friend")
                .analyzeIntent(true)
                .build();
        when(geminiAiService.interactWithGemini(eq("user-1"), any(AiChatRequest.class)))
                .thenThrow(new RuntimeException("AI_SERVICE_ERROR"));

        ResponseEntity<?> entity = controller.interactWithMascot(request);

        assertEquals(200, entity.getStatusCode().value());
        ApiResponse<?> body = (ApiResponse<?>) entity.getBody();
        assertNotNull(body);
        AiChatResponse data = (AiChatResponse) body.getData();
        assertNotNull(data);
        assertNull(data.getActionCommand());
        assertNull(data.getActionParams());
        assertTrue(data.getTextReply().contains("chua xac dinh duoc nguoi can goi"));
        assertTrue(data.isDegraded());
        assertEquals("AI_PROVIDER_UNAVAILABLE", data.getProviderStatus());
    }

    @Test
    void interactWithMascot_shouldPreserveLocalCallCommandWithClearTargetWhenProvidersFail() {
        authenticateTestUser();
        AiInteractionController controller = new AiInteractionController(geminiAiService, chatService);
        AiChatRequest request = AiChatRequest.builder()
                .prompt("Hay goi video cho me giup minh")
                .analyzeIntent(true)
                .build();
        when(geminiAiService.interactWithGemini(eq("user-1"), any(AiChatRequest.class)))
                .thenThrow(new RuntimeException("AI_SERVICE_ERROR"));

        ResponseEntity<?> entity = controller.interactWithMascot(request);

        assertEquals(200, entity.getStatusCode().value());
        ApiResponse<?> body = (ApiResponse<?>) entity.getBody();
        assertNotNull(body);
        AiChatResponse data = (AiChatResponse) body.getData();
        assertNotNull(data);
        assertEquals("START_CALL", data.getActionCommand());
        assertEquals("me", data.getActionParams().get("target"));
        assertEquals("video", data.getActionParams().get("callType"));
        assertEquals(Boolean.TRUE, data.getRequiresConfirmation());
        assertEquals("medium", data.getRiskLevel());
        assertTrue(data.isDegraded());
        assertEquals("AI_PROVIDER_UNAVAILABLE", data.getProviderStatus());
    }
}
