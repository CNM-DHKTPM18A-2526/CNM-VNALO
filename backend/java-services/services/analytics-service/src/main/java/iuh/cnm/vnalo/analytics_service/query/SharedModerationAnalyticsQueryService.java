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
public class SharedModerationAnalyticsQueryService {
    private final NamedParameterJdbcTemplate jdbcTemplate;

    private Timestamp toUtcTimestamp(LocalDate date) {
        return Timestamp.from(date.atStartOfDay(ZoneOffset.UTC).toInstant());
    }

    public long countReports(LocalDate from, LocalDate to) {
        String sql = """
            SELECT COUNT(*)
            FROM moderation_report
            WHERE created_at >= :from
              AND created_at < :toPlusOne
            """;

        MapSqlParameterSource params = new MapSqlParameterSource()
            .addValue("from", toUtcTimestamp(from))
            .addValue("toPlusOne", toUtcTimestamp(to.plusDays(1)));

        return jdbcTemplate.queryForObject(sql, params, Long.class);
    }

    public long countModerationActions(LocalDate from, LocalDate to) {
        String sql = """
            SELECT COUNT(*)
            FROM moderation_action
            WHERE created_at >= :from
              AND created_at < :toPlusOne
            """;

        MapSqlParameterSource params = new MapSqlParameterSource()
            .addValue("from", toUtcTimestamp(from))
            .addValue("toPlusOne", toUtcTimestamp(to.plusDays(1)));

        return jdbcTemplate.queryForObject(sql, params, Long.class);
    }

    public List<DailyTrendPointResponse> getReportTrend(LocalDate from, LocalDate to) {
        String sql = """
                        SELECT CAST(created_at AS DATE) AS metric_date, COUNT(*) AS metric_value
            FROM moderation_report
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

    public List<DailyTrendPointResponse> getModerationActionTrend(LocalDate from, LocalDate to) {
        String sql = """
                        SELECT CAST(created_at AS DATE) AS metric_date, COUNT(*) AS metric_value
            FROM moderation_action
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

    public List<ReasonCountResponse> getReportReasonBreakdown(LocalDate from, LocalDate to) {
        String sql = """
            SELECT reason_code, COUNT(*) AS cnt
            FROM moderation_report
            WHERE created_at >= :from
              AND created_at < :toPlusOne
            GROUP BY reason_code
            ORDER BY cnt DESC
            """;

        MapSqlParameterSource params = new MapSqlParameterSource()
            .addValue("from", toUtcTimestamp(from))
            .addValue("toPlusOne", toUtcTimestamp(to.plusDays(1)));

        return jdbcTemplate.query(sql, params, (rs, rowNum) ->
                ReasonCountResponse.builder()
                        .key(rs.getString("reason_code"))
                        .value(rs.getLong("cnt"))
                        .build()
        );
    }

    public List<ReasonCountResponse> getReportTargetTypeBreakdown(LocalDate from, LocalDate to) {
        String sql = """
            SELECT target_type, COUNT(*) AS cnt
            FROM moderation_report
            WHERE created_at >= :from
              AND created_at < :toPlusOne
            GROUP BY target_type
            ORDER BY cnt DESC
            """;

        MapSqlParameterSource params = new MapSqlParameterSource()
            .addValue("from", toUtcTimestamp(from))
            .addValue("toPlusOne", toUtcTimestamp(to.plusDays(1)));

        return jdbcTemplate.query(sql, params, (rs, rowNum) ->
                ReasonCountResponse.builder()
                        .key(rs.getString("target_type"))
                        .value(rs.getLong("cnt"))
                        .build()
        );
    }
}