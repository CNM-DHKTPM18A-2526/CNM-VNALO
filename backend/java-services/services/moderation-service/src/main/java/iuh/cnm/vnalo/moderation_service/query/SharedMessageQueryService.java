package iuh.cnm.vnalo.moderation_service.query;

import com.fasterxml.jackson.databind.ObjectMapper;
import iuh.cnm.vnalo.moderation_service.exception.ApiException;
import iuh.cnm.vnalo.moderation_service.exception.ErrorCode;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class SharedMessageQueryService {
    private final NamedParameterJdbcTemplate jdbcTemplate;
    private final ObjectMapper objectMapper;

    public String getMessageSnapshotJson(UUID messageId) {
        String sql = """
            SELECT jsonb_build_object(
                'messageId', m.message_id,
                'conversationId', m.conversation_id,
                'senderId', m.sender_id,
                'content', m.content,
                'messageType', m.message_type,
                'status', m.status,
                'createdAt', m.created_at
            )::text
            FROM message m
            WHERE m.message_id = :messageId
            """;

        MapSqlParameterSource params = new MapSqlParameterSource("messageId", messageId);
        List<String> rows = jdbcTemplate.query(sql, params, (rs, rowNum) -> rs.getString(1));
        if (rows.isEmpty()) {
            throw new ApiException(ErrorCode.MODERATION_TARGET_NOT_FOUND);
        }
        return rows.get(0);
    }
}