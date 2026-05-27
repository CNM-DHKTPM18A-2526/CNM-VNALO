package iuh.cnm.vnalo.aiservice.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import iuh.cnm.vnalo.aiservice.dto.external.MascotSettingsDTO;
import iuh.cnm.vnalo.aiservice.dto.request.AiChatRequest;
import iuh.cnm.vnalo.aiservice.dto.response.AiChatResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpMethod;
import org.springframework.http.ResponseEntity;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.web.client.RestTemplate;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doNothing;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class GeminiAiServiceTest {

    @Mock
    private RestTemplate geminiRestTemplate;
    @Mock
    private CoreServiceClient coreServiceClient;
    @Mock
    private OllamaProvider ollamaProvider;
    @Mock
    private ChatService chatService;

    private GeminiAiService geminiAiService;

    @BeforeEach
    void setUp() {
        geminiAiService = new GeminiAiService(
                geminiRestTemplate,
                new ObjectMapper(),
                coreServiceClient,
                ollamaProvider,
                chatService
        );
        ReflectionTestUtils.setField(geminiAiService, "modelName", "gemini-2.5-flash");

        doNothing().when(chatService).enforceUserRateLimit("user-1");
        doNothing().when(chatService).enforceGlobalRateLimit();
        when(coreServiceClient.getUserMascotSettings("user-1")).thenReturn(new MascotSettingsDTO());
    }

    @Test
    void interactWithGemini_normalizesAliasAndStructuredParams() {
        String responseJson = """
                {
                  "candidates": [
                    {
                      "content": {
                        "parts": [
                          {
                            "text": "{\\\"textReply\\\":\\\"Prepared the message.\\\",\\\"action\\\":\\\"send_message\\\",\\\"params\\\":{\\\"target\\\":\\\"Ly Tinh Van\\\",\\\"messageText\\\":\\\"I will arrive in 10 minutes\\\"},\\\"emotion\\\":\\\"joyful\\\"}"
                          }
                        ]
                      }
                    }
                  ]
                }
                """;

        when(geminiRestTemplate.exchange(
                eq("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"),
                eq(HttpMethod.POST),
                any(),
                eq(String.class)
        )).thenReturn(ResponseEntity.ok(responseJson));

        AiChatResponse response = geminiAiService.interactWithGemini(
                "user-1",
                AiChatRequest.builder()
                        .prompt("Message Ly Tinh Van that I will arrive in 10 minutes")
                        .analyzeIntent(true)
                        .history(List.of())
                        .build()
        );

        assertEquals("COMPOSE_MESSAGE", response.getActionCommand());
        assertEquals("Ly Tinh Van", response.getActionParams().get("recipient"));
        assertEquals("I will arrive in 10 minutes", response.getActionParams().get("content"));
        assertEquals("Prepared the message.", response.getTextReply());
        assertEquals("LIVE_PROVIDER_ACTIVE", response.getProviderStatus());
        assertFalse(response.isDegraded());
        assertNotNull(response.getConversationId());
        assertTrue(response.getRequiresConfirmation());
        assertEquals("medium", response.getRiskLevel());
    }

    @Test
    void interactWithGemini_acceptsGroupManagementCommands() {
        String responseJson = """
                {
                  "candidates": [
                    {
                      "content": {
                        "parts": [
                          {
                            "text": "{\\\"textReply\\\":\\\"Prepared create group action.\\\",\\\"actionCommand\\\":\\\"CREATE_GROUP\\\",\\\"actionParams\\\":{\\\"title\\\":\\\"Nhom do an\\\",\\\"members\\\":[\\\"An\\\",\\\"Binh\\\"]},\\\"emotion\\\":\\\"thinking\\\"}"
                          }
                        ]
                      }
                    }
                  ]
                }
                """;

        when(geminiRestTemplate.exchange(any(String.class), eq(HttpMethod.POST), any(), eq(String.class)))
                .thenReturn(ResponseEntity.ok(responseJson));

        AiChatResponse response = geminiAiService.interactWithGemini(
                "user-1",
                AiChatRequest.builder()
                        .prompt("Create a project group with An and Binh")
                        .analyzeIntent(true)
                        .build()
        );

        assertEquals("CREATE_GROUP", response.getActionCommand());
        assertEquals("Nhom do an", response.getActionParams().get("groupName"));
        assertEquals(List.of("An", "Binh"), response.getActionParams().get("memberNames"));
        assertTrue(response.getRequiresConfirmation());
        assertEquals("medium", response.getRiskLevel());
    }

    @Test
    void interactWithGemini_blocksInvalidActionSchema() {
        String responseJson = """
                {
                  "candidates": [
                    {
                      "content": {
                        "parts": [
                          {
                            "text": "{\\\"textReply\\\":\\\"I will open profile.\\\",\\\"actionCommand\\\":\\\"OPEN_PROFILE\\\",\\\"actionParams\\\":{\\\"foo\\\":\\\"bar\\\"},\\\"emotion\\\":\\\"thinking\\\"}"
                          }
                        ]
                      }
                    }
                  ]
                }
                """;

        when(geminiRestTemplate.exchange(any(String.class), eq(HttpMethod.POST), any(), eq(String.class)))
                .thenReturn(ResponseEntity.ok(responseJson));

        AiChatResponse response = geminiAiService.interactWithGemini(
                "user-1",
                AiChatRequest.builder()
                        .prompt("Open Van profile")
                        .analyzeIntent(true)
                        .build()
        );

        assertNull(response.getActionCommand());
        assertNull(response.getActionParams());
        assertEquals("I will open profile.", response.getTextReply());
        assertFalse(response.getRequiresConfirmation());
        assertEquals("low", response.getRiskLevel());
    }


    @Test
    void interactWithGemini_rewritesPrematureSuccessComposeCopy() {
        String responseJson = """
                {
                  "candidates": [
                    {
                      "content": {
                        "parts": [
                          {
                            "text": "{\\\"textReply\\\":\\\"I already sent the message.\\\",\\\"actionCommand\\\":\\\"COMPOSE_MESSAGE\\\",\\\"actionParams\\\":{\\\"recipient\\\":\\\"Ly Tinh Van\\\",\\\"content\\\":\\\"Hello\\\"},\\\"emotion\\\":\\\"joyful\\\"}"
                          }
                        ]
                      }
                    }
                  ]
                }
                """;

        when(geminiRestTemplate.exchange(any(String.class), eq(HttpMethod.POST), any(), eq(String.class)))
                .thenReturn(ResponseEntity.ok(responseJson));

        AiChatResponse response = geminiAiService.interactWithGemini(
                "user-1",
                AiChatRequest.builder()
                        .prompt("Message Ly Tinh Van Hello")
                        .analyzeIntent(true)
                        .build()
        );

        assertEquals("COMPOSE_MESSAGE", response.getActionCommand());
        assertEquals("Ly Tinh Van", response.getActionParams().get("recipient"));
        assertEquals("Hello", response.getActionParams().get("content"));
        assertNotEquals("I already sent the message.", response.getTextReply());
        assertFalse(response.getTextReply().toLowerCase().contains("sent the message"));
        assertTrue(response.getRequiresConfirmation());
        assertEquals("medium", response.getRiskLevel());
    }

    @Test
    void interactWithGemini_rewritesPrematureSuccessCallCopy() {
        String responseJson = """
                {
                  "candidates": [
                    {
                      "content": {
                        "parts": [
                          {
                            "text": "{\\\"textReply\\\":\\\"I already started the call.\\\",\\\"actionCommand\\\":\\\"START_CALL\\\",\\\"actionParams\\\":{\\\"target\\\":\\\"Ly Tinh Van\\\",\\\"callType\\\":\\\"voice\\\"},\\\"emotion\\\":\\\"thinking\\\"}"
                          }
                        ]
                      }
                    }
                  ]
                }
                """;

        when(geminiRestTemplate.exchange(any(String.class), eq(HttpMethod.POST), any(), eq(String.class)))
                .thenReturn(ResponseEntity.ok(responseJson));

        AiChatResponse response = geminiAiService.interactWithGemini(
                "user-1",
                AiChatRequest.builder()
                        .prompt("Call Ly Tinh Van")
                        .analyzeIntent(true)
                        .build()
        );

        assertEquals("START_CALL", response.getActionCommand());
        assertEquals("Ly Tinh Van", response.getActionParams().get("target"));
        assertTrue(response.getTextReply().contains("chat AI"));
        assertFalse(response.getTextReply().toLowerCase().contains("already started"));
        assertTrue(response.getRequiresConfirmation());
        assertEquals("medium", response.getRiskLevel());
    }

    @Test
    void interactWithGemini_marksFallbackResponsesAsDegraded() {
        when(geminiRestTemplate.exchange(any(String.class), eq(HttpMethod.POST), any(), eq(String.class)))
                .thenThrow(new RuntimeException("Gemini unavailable"));
        when(ollamaProvider.generate(any(), any())).thenReturn("""
                {"textReply":"Fallback route is active.","actionCommand":"NAVIGATE_TO_CONTACTS","actionParams":{},"emotion":"thinking"}
                """);

        AiChatResponse response = geminiAiService.interactWithGemini(
                "user-1",
                AiChatRequest.builder()
                        .prompt("Open contacts")
                        .analyzeIntent(true)
                        .build()
        );

        assertEquals("NAVIGATE_TO_CONTACTS", response.getActionCommand());
        assertEquals("FALLBACK_PROVIDER_ACTIVE", response.getProviderStatus());
        assertTrue(response.isDegraded());
        assertFalse(response.getRequiresConfirmation());
        assertEquals("low", response.getRiskLevel());
    }
}

