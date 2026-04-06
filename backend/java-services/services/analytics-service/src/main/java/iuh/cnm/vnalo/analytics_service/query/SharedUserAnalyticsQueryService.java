package iuh.cnm.vnalo.analytics_service.query;

import iuh.cnm.vnalo.analytics_service.model.dto.response.DailyTrendPointResponse;
import iuh.cnm.vnalo.analytics_service.model.dto.response.TopActiveUserResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;

import java.sql.Timestamp;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.UUID;
import java.util.List;

@Service
@RequiredArgsConstructor
public class SharedUserAnalyticsQueryService {
    private final NamedParameterJdbcTemplate jdbcTemplate;

    private Timestamp toUtcTimestamp(LocalDate date) {
        return Timestamp.from(date.atStartOfDay(ZoneOffset.UTC).toInstant());
    }

    public long countRegisteredUsers(LocalDate from, LocalDate to) {
        String sql = """
            SELECT COUNT(*)
            FROM auth_account
            WHERE created_at >= :from
              AND created_at < :toPlusOne
            """;

        MapSqlParameterSource params = new MapSqlParameterSource()
            .addValue("from", toUtcTimestamp(from))
            .addValue("toPlusOne", toUtcTimestamp(to.plusDays(1)));

        return jdbcTemplate.queryForObject(sql, params, Long.class);
    }

    public List<DailyTrendPointResponse> getUserRegistrationTrend(LocalDate from, LocalDate to) {
        String sql = """
                        SELECT CAST(created_at AS DATE) AS metric_date, COUNT(*) AS metric_value
            FROM auth_account
            WHERE created_at >= :from
              AND created_at < :toPlusOne
                        GROUP BY CAST(created_at AS DATE)
            ORDER BY metric_date
            """;

        MapSqlParameterSource params = new MapSqlParameterSource()
            .addValue("from", toUtcTimestamp(from))
            .addValue("toPlusOne", toUtcTimestamp(to.plusDays(1)));

        return jdbcTemplate.query(sql, params, (rs, rowNum) ->
                DailyTrendPointResponse.builder()
                        .date(rs.getDate("metric_date").toLocalDate())
                        .value(rs.getLong("metric_value"))
                        .build()
        );
    }

    public long countDistinctActiveUsers(LocalDate from, LocalDate to) {
        String sql = """
            SELECT COUNT(DISTINCT sender_id)
            FROM message
            WHERE created_at >= :from
              AND created_at < :toPlusOne
            """;

        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("from", toUtcTimestamp(from))
                .addValue("toPlusOne", toUtcTimestamp(to.plusDays(1)));

        return jdbcTemplate.queryForObject(sql, params, Long.class);
    }

    public List<TopActiveUserResponse> getTopActiveUsers(LocalDate from, LocalDate to, int limit) {
        String sql = """
            SELECT m.sender_id AS user_id,
                   COALESCE(up.display_name, 'Unknown') AS display_name,
                   COUNT(*) AS message_count
            FROM message m
            LEFT JOIN user_profile up ON up.user_id = m.sender_id
            WHERE m.created_at >= :from
              AND m.created_at < :toPlusOne
            GROUP BY m.sender_id, up.display_name
            ORDER BY message_count DESC
            LIMIT :limit
            """;

        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("from", toUtcTimestamp(from))
                .addValue("toPlusOne", toUtcTimestamp(to.plusDays(1)))
                .addValue("limit", limit);

        return jdbcTemplate.query(sql, params, (rs, rowNum) ->
                TopActiveUserResponse.builder()
                        .userId(rs.getObject("user_id", UUID.class))
                        .displayName(rs.getString("display_name"))
                        .messageCount(rs.getLong("message_count"))
                        .build()
        );
    }
}