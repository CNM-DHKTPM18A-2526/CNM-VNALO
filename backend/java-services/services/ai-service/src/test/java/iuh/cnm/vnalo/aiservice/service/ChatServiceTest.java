package iuh.cnm.vnalo.aiservice.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import iuh.cnm.vnalo.aiservice.dto.Message;
import iuh.cnm.vnalo.aiservice.dto.ChatResponse;
import iuh.cnm.vnalo.aiservice.exception.RateLimitExceededException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.List;
import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.argThat;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ChatServiceTest {

    @Mock
    private GeminiProvider geminiProvider;
    @Mock
    private OllamaProvider ollamaProvider;
    @Mock
    private StringRedisTemplate redisTemplate;
    @Mock
    private ValueOperations<String, String> valueOperations;

    private ChatService chatService;

    @BeforeEach
    void setUp() {
        chatService = new ChatService(geminiProvider, ollamaProvider, redisTemplate);
        when(redisTemplate.opsForValue()).thenReturn(valueOperations);

        ReflectionTestUtils.setField(chatService, "rateLimitPerUser", 5);
        ReflectionTestUtils.setField(chatService, "rateLimitGlobal", 10);
        ReflectionTestUtils.setField(chatService, "maxHistory", 20);
        ReflectionTestUtils.setField(chatService, "historyTtl", 86400L);
    }

    @Test
    void ask_shouldFallbackToOllamaWithoutGlobalCounterWhenGeminiUnavailable() {
        when(geminiProvider.isAvailable()).thenReturn(false);
        when(ollamaProvider.generate(anyString(), org.mockito.ArgumentMatchers.anyList())).thenReturn("fallback");
        when(valueOperations.increment(argThat(key -> key != null && key.startsWith("rl:ai:user:")))).thenReturn(1L);
        when(valueOperations.get(anyString())).thenReturn(null);
        when(redisTemplate.expire(anyString(), anyLong(), eq(TimeUnit.SECONDS))).thenReturn(true);

        ChatResponse response = chatService.ask("u1", "hello", "c1");

        assertEquals("ollama", response.getProvider());
        verify(valueOperations, never()).increment(argThat(key -> key.startsWith("rl:ai:global:")));
    }

    @Test
    void ask_shouldThrowWhenPerUserRateLimitExceeded() {
        when(valueOperations.increment(argThat(key -> key != null && key.startsWith("rl:ai:user:")))).thenReturn(6L);

        assertThrows(RateLimitExceededException.class, () -> chatService.ask("u1", "hello", "c1"));
    }

    @Test
    void ask_shouldTrimAndPersistHistoryByMaxHistory() throws Exception {
        ReflectionTestUtils.setField(chatService, "maxHistory", 3);

        List<Message> existing = List.of(
                new Message("user", "m1"),
                new Message("assistant", "m2"),
                new Message("user", "m3")
        );
        ObjectMapper mapper = new ObjectMapper();

        when(geminiProvider.isAvailable()).thenReturn(true);
        when(geminiProvider.generate(anyString(), org.mockito.ArgumentMatchers.anyList())).thenReturn("m4");
        when(valueOperations.increment(argThat(key -> key != null && key.startsWith("rl:ai:user:")))).thenReturn(1L);
        when(valueOperations.increment(argThat(key -> key != null && key.startsWith("rl:ai:global:")))).thenReturn(1L);
        when(valueOperations.get("ai:history:u1:c1")).thenReturn(mapper.writeValueAsString(existing));
        when(redisTemplate.expire(anyString(), anyLong(), eq(TimeUnit.SECONDS))).thenReturn(true);

        chatService.ask("u1", "new", "c1");

        ArgumentCaptor<String> rawCaptor = ArgumentCaptor.forClass(String.class);
        verify(valueOperations).set(eq("ai:history:u1:c1"), rawCaptor.capture(), eq(86400L), eq(TimeUnit.SECONDS));

        List<Message> saved = mapper.readValue(rawCaptor.getValue(), new TypeReference<>() {});
        assertEquals(3, saved.size());
        assertEquals("m3", saved.get(0).getContent());
        assertEquals("new", saved.get(1).getContent());
        assertEquals("m4", saved.get(2).getContent());
        assertTrue(saved.stream().noneMatch(msg -> "m1".equals(msg.getContent())));
    }
}
