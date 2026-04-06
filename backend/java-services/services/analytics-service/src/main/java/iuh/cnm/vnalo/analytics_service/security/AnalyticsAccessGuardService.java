package iuh.cnm.vnalo.analytics_service.security;

import iuh.cnm.vnalo.analytics_service.exception.ApiException;
import iuh.cnm.vnalo.analytics_service.exception.ErrorCode;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AnalyticsAccessGuardService {
    private final NamedParameterJdbcTemplate jdbcTemplate;

    public void requireAnalyticsAccess(UUID userId) {
        String sql = """
            SELECT COUNT(*)
            FROM moderation_admin_user
            WHERE user_id = :userId
              AND is_active = TRUE
              AND role IN ('MODERATOR', 'ADMIN')
            """;

        Long count = jdbcTemplate.queryForObject(sql, new MapSqlParameterSource("userId", userId), Long.class);
        if (count == null || count == 0) {
            throw new ApiException(ErrorCode.ANALYTICS_FORBIDDEN);
        }
    }

    public void requireAnalyticsAdmin(UUID userId) {
        String sql = """
            SELECT COUNT(*)
            FROM moderation_admin_user
            WHERE user_id = :userId
              AND is_active = TRUE
              AND role = 'ADMIN'
            """;

        Long count = jdbcTemplate.queryForObject(sql, new MapSqlParameterSource("userId", userId), Long.class);
        if (count == null || count == 0) {
            throw new ApiException(ErrorCode.ANALYTICS_FORBIDDEN);
        }
    }
}