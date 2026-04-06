package iuh.cnm.vnalo.analytics_service.query;

import iuh.cnm.vnalo.analytics_service.model.dto.response.DailyTrendPointResponse;
import iuh.cnm.vnalo.analytics_service.model.dto.response.MessageTypeCountResponse;
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
public class SharedMessageAnalyticsQueryService {
    private final NamedParameterJdbcTemplate jdbcTemplate;

    private Timestamp toUtcTimestamp(LocalDate date) {
        return Timestamp.from(date.atStartOfDay(ZoneOffset.UTC).toInstant());
    }

    public long countMessagesSent(LocalDate from, LocalDate to) {
        String sql = """
            SELECT COUNT(*)
            FROM message
            WHERE created_at >= :from
              AND created_at < :toPlusOne
            """;

        MapSqlParameterSource params = new MapSqlParameterSource()
            .addValue("from", toUtcTimestamp(from))
            .addValue("toPlusOne", toUtcTimestamp(to.plusDays(1)));

        return jdbcTemplate.queryForObject(sql, params, Long.class);
    }

    public List<DailyTrendPointResponse> getMessageTrend(LocalDate from, LocalDate to) {
        String sql = """
                        SELECT CAST(created_at AS DATE) AS metric_date, COUNT(*) AS metric_value
            FROM message
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

    public List<MessageTypeCountResponse> getMessageTypeBreakdown(LocalDate from, LocalDate to) {
        String sql = """
            SELECT message_type, COUNT(*) AS cnt
            FROM message
            WHERE created_at >= :from
              AND created_at < :toPlusOne
            GROUP BY message_type
            ORDER BY cnt DESC
            """;

        MapSqlParameterSource params = new MapSqlParameterSource()
            .addValue("from", toUtcTimestamp(from))
            .addValue("toPlusOne", toUtcTimestamp(to.plusDays(1)));

        return jdbcTemplate.query(sql, params, (rs, rowNum) ->
                MessageTypeCountResponse.builder()
                        .messageType(rs.getString("message_type"))
                        .count(rs.getLong("cnt"))
                        .build()
        );
    }

    public List<DailyTrendPointResponse> getMediaTrend(LocalDate from, LocalDate to) {
        String sql = """
                        SELECT CAST(created_at AS DATE) AS metric_date, COUNT(*) AS metric_value
            FROM message
            WHERE created_at >= :from
              AND created_at < :toPlusOne
              AND message_type IN ('IMAGE', 'VIDEO', 'FILE', 'AUDIO', 'STICKER')
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