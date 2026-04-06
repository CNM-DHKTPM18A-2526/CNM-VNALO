package iuh.cnm.vnalo.analytics_service.query;

import iuh.cnm.vnalo.analytics_service.model.dto.response.DailyTrendPointResponse;
import iuh.cnm.vnalo.analytics_service.model.dto.response.ReasonCountResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;

import java.sql.Timestamp;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;

@Service
@RequiredArgsConstructor
public class SharedConversationAnalyticsQueryService {
    private final NamedParameterJdbcTemplate jdbcTemplate;

    private Timestamp toUtcTimestamp(LocalDate date) {
        return Timestamp.from(date.atStartOfDay(ZoneOffset.UTC).toInstant());
    }

    public long countCreatedConversations(LocalDate from, LocalDate to) {
        String sql = """
            SELECT COUNT(*)
            FROM conversation
            WHERE created_at >= :from
              AND created_at < :toPlusOne
            """;

        MapSqlParameterSource params = new MapSqlParameterSource()
            .addValue("from", toUtcTimestamp(from))
            .addValue("toPlusOne", toUtcTimestamp(to.plusDays(1)));

        return jdbcTemplate.queryForObject(sql, params, Long.class);
    }

    public List<DailyTrendPointResponse> getConversationTrend(LocalDate from, LocalDate to) {
        String sql = """
                        SELECT CAST(created_at AS DATE) AS metric_date, COUNT(*) AS metric_value
            FROM conversation
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

    public List<ReasonCountResponse> getConversationTypeBreakdown(LocalDate from, LocalDate to) {
        String sql = """
            SELECT type, COUNT(*) AS cnt
            FROM conversation
            WHERE created_at >= :from
              AND created_at < :toPlusOne
            GROUP BY type
            ORDER BY cnt DESC
            """;

        MapSqlParameterSource params = new MapSqlParameterSource()
            .addValue("from", toUtcTimestamp(from))
            .addValue("toPlusOne", toUtcTimestamp(to.plusDays(1)));

        return jdbcTemplate.query(sql, params, (rs, rowNum) ->
                ReasonCountResponse.builder()
                        .key(rs.getString("type"))
                        .value(rs.getLong("cnt"))
                        .build()
        );
    }

    public List<DailyTrendPointResponse> getGroupCreationTrend(LocalDate from, LocalDate to) {
        String sql = """
                        SELECT CAST(created_at AS DATE) AS metric_date, COUNT(*) AS metric_value
            FROM conversation
            WHERE created_at >= :from
              AND created_at < :toPlusOne
              AND type = 'GROUP'
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
}