package iuh.cnm.vnalo.moderation_service.query;

import iuh.cnm.vnalo.moderation_service.exception.ApiException;
import iuh.cnm.vnalo.moderation_service.exception.ErrorCode;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class SharedUserQueryService {
    private final NamedParameterJdbcTemplate jdbcTemplate;

    public String getUserSnapshotJson(UUID userId) {
        String sql = """
            SELECT jsonb_build_object(
                'userId', up.id,
                'displayName', up.display_name,
                'avatarUrl', up.avatar_url,
                'bio', up.bio,
                'isVerified', up.is_verified,
                'phone', aa.phone,
                'status', aa.status
            )::text
            FROM user_profile up
            JOIN auth_account aa ON aa.id = up.id
            WHERE up.id = :userId
            """;

        MapSqlParameterSource params = new MapSqlParameterSource("userId", userId);
        List<String> rows = jdbcTemplate.query(sql, params, (rs, rowNum) -> rs.getString(1));
        if (rows.isEmpty()) {
            throw new ApiException(ErrorCode.MODERATION_TARGET_NOT_FOUND);
        }
        return rows.get(0);
    }
}