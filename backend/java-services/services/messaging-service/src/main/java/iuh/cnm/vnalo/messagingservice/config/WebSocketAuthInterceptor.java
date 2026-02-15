package iuh.cnm.vnalo.messagingservice.config;

import iuh.cnm.vnalo.messagingservice.security.JwtTokenProvider;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.stereotype.Component;

import java.security.Principal;
import java.util.Collections;
import java.util.List;
import java.util.UUID;

/**
 * Intercepts STOMP CONNECT frames to authenticate WebSocket connections via JWT.
 * The token can be passed as:
 * 1. STOMP header: "Authorization: Bearer <token>"
 * 2. Query parameter: ?token=<token> (handled at transport level, Sec-WebSocket-Protocol)
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class WebSocketAuthInterceptor implements ChannelInterceptor {

    private final JwtTokenProvider jwtTokenProvider;

    @Override
    public Message<?> preSend(Message<?> message, MessageChannel channel) {
        StompHeaderAccessor accessor = MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor.class);

        if (accessor != null && StompCommand.CONNECT.equals(accessor.getCommand())) {
            String token = extractToken(accessor);

            if (token != null && jwtTokenProvider.validateToken(token)) {
                String userId = jwtTokenProvider.getUserIdFromToken(token);
                Principal principal = new UsernamePasswordAuthenticationToken(
                        UUID.fromString(userId), null, Collections.emptyList());
                accessor.setUser(principal);
                log.debug("WebSocket authenticated for user: {}", userId);
            } else {
                log.warn("WebSocket connection rejected: invalid or missing JWT");
                throw new IllegalArgumentException("Invalid or missing JWT token");
            }
        }

        return message;
    }

    private String extractToken(StompHeaderAccessor accessor) {
        // Try STOMP header first
        List<String> authHeaders = accessor.getNativeHeader("Authorization");
        if (authHeaders != null && !authHeaders.isEmpty()) {
            String header = authHeaders.get(0);
            if (header.startsWith("Bearer ")) {
                return header.substring(7);
            }
            return header;
        }

        // Try "token" header (simpler for frontend)
        List<String> tokenHeaders = accessor.getNativeHeader("token");
        if (tokenHeaders != null && !tokenHeaders.isEmpty()) {
            return tokenHeaders.get(0);
        }

        return null;
    }
}
