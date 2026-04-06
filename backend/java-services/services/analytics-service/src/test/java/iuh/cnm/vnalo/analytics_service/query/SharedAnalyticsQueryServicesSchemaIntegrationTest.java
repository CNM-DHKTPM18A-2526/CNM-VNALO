package iuh.cnm.vnalo.analytics_service.query;

import iuh.cnm.vnalo.analytics_service.model.dto.response.DailyTrendPointResponse;
import iuh.cnm.vnalo.analytics_service.model.dto.response.MessageTypeCountResponse;
import iuh.cnm.vnalo.analytics_service.model.dto.response.ReasonCountResponse;
import iuh.cnm.vnalo.analytics_service.model.dto.response.TopActiveUserResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

import java.sql.Timestamp;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest
@ActiveProfiles("test")
class SharedAnalyticsQueryServicesSchemaIntegrationTest {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private SharedUserAnalyticsQueryService userQueryService;

    @Autowired
    private SharedConversationAnalyticsQueryService conversationQueryService;

    @Autowired
    private SharedMessageAnalyticsQueryService messageQueryService;

    @Autowired
    private SharedModerationAnalyticsQueryService moderationQueryService;

    private static final UUID USER_A = UUID.fromString("11111111-1111-1111-1111-111111111111");
    private static final UUID USER_B = UUID.fromString("22222222-2222-2222-2222-222222222222");
    private static final UUID USER_C = UUID.fromString("33333333-3333-3333-3333-333333333333");

    @BeforeEach
    void setUpSchemaAndData() {
        resetSchema();
        seedData();
    }

    @Test
    void userConversationAndMessageQueries_shouldWorkAgainstLocalSchema() {
        LocalDate from = LocalDate.of(2026, 3, 20);
        LocalDate to = LocalDate.of(2026, 3, 21);

        assertThat(userQueryService.countRegisteredUsers(from, to)).isEqualTo(3L);
        assertThat(userQueryService.countDistinctActiveUsers(from, to)).isEqualTo(2L);

        List<DailyTrendPointResponse> userTrend = userQueryService.getUserRegistrationTrend(from, to);
        assertThat(userTrend).extracting(DailyTrendPointResponse::getDate)
                .containsExactly(LocalDate.of(2026, 3, 20), LocalDate.of(2026, 3, 21));
        assertThat(userTrend).extracting(DailyTrendPointResponse::getValue)
                .containsExactly(2L, 1L);

        List<TopActiveUserResponse> topUsers = userQueryService.getTopActiveUsers(from, to, 2);
        assertThat(topUsers).hasSize(2);
        assertThat(topUsers.get(0).getUserId()).isEqualTo(USER_A);
        assertThat(topUsers.get(0).getDisplayName()).isEqualTo("Alice");
        assertThat(topUsers.get(0).getMessageCount()).isEqualTo(3L);

        assertThat(conversationQueryService.countCreatedConversations(from, to)).isEqualTo(3L);

        List<DailyTrendPointResponse> conversationTrend = conversationQueryService.getConversationTrend(from, to);
        assertThat(conversationTrend).extracting(DailyTrendPointResponse::getValue)
                .containsExactly(2L, 1L);

        List<ReasonCountResponse> conversationTypes = conversationQueryService.getConversationTypeBreakdown(from, to);
        assertThat(conversationTypes).extracting(ReasonCountResponse::getKey)
                .containsExactly("GROUP", "DIRECT");
        assertThat(conversationTypes).extracting(ReasonCountResponse::getValue)
                .containsExactly(2L, 1L);

        List<DailyTrendPointResponse> groupTrend = conversationQueryService.getGroupCreationTrend(from, to);
        assertThat(groupTrend).extracting(DailyTrendPointResponse::getValue)
                .containsExactly(1L, 1L);

        assertThat(messageQueryService.countMessagesSent(from, to)).isEqualTo(4L);

        List<DailyTrendPointResponse> messageTrend = messageQueryService.getMessageTrend(from, to);
        assertThat(messageTrend).extracting(DailyTrendPointResponse::getValue)
                .containsExactly(2L, 2L);

        List<MessageTypeCountResponse> messageTypes = messageQueryService.getMessageTypeBreakdown(from, to);
        assertThat(messageTypes)
                .extracting(MessageTypeCountResponse::getMessageType, MessageTypeCountResponse::getCount)
                .containsExactlyInAnyOrder(
                        org.assertj.core.groups.Tuple.tuple("TEXT", 2L),
                        org.assertj.core.groups.Tuple.tuple("IMAGE", 1L),
                        org.assertj.core.groups.Tuple.tuple("VIDEO", 1L)
                );

        List<DailyTrendPointResponse> mediaTrend = messageQueryService.getMediaTrend(from, to);
        assertThat(mediaTrend).extracting(DailyTrendPointResponse::getValue)
                .containsExactly(1L, 1L);
    }

    @Test
    void moderationQueries_shouldWorkAgainstLocalSchema() {
        LocalDate from = LocalDate.of(2026, 3, 20);
        LocalDate to = LocalDate.of(2026, 3, 21);

        assertThat(moderationQueryService.countReports(from, to)).isEqualTo(3L);
        assertThat(moderationQueryService.countModerationActions(from, to)).isEqualTo(2L);

        List<DailyTrendPointResponse> reportTrend = moderationQueryService.getReportTrend(from, to);
        assertThat(reportTrend).extracting(DailyTrendPointResponse::getValue)
                .containsExactly(1L, 2L);

        List<DailyTrendPointResponse> actionTrend = moderationQueryService.getModerationActionTrend(from, to);
        assertThat(actionTrend).extracting(DailyTrendPointResponse::getValue)
                .containsExactly(1L, 1L);

        List<ReasonCountResponse> reasonBreakdown = moderationQueryService.getReportReasonBreakdown(from, to);
        assertThat(reasonBreakdown).extracting(ReasonCountResponse::getKey)
                .containsExactly("SPAM", "ABUSE");
        assertThat(reasonBreakdown).extracting(ReasonCountResponse::getValue)
                .containsExactly(2L, 1L);

        List<ReasonCountResponse> targetTypeBreakdown = moderationQueryService.getReportTargetTypeBreakdown(from, to);
        assertThat(targetTypeBreakdown).extracting(ReasonCountResponse::getKey)
                .containsExactly("USER", "MESSAGE");
        assertThat(targetTypeBreakdown).extracting(ReasonCountResponse::getValue)
                .containsExactly(2L, 1L);
    }

    private void resetSchema() {
        jdbcTemplate.execute("DROP TABLE IF EXISTS moderation_action");
        jdbcTemplate.execute("DROP TABLE IF EXISTS moderation_report");
        jdbcTemplate.execute("DROP TABLE IF EXISTS message");
        jdbcTemplate.execute("DROP TABLE IF EXISTS conversation");
        jdbcTemplate.execute("DROP TABLE IF EXISTS user_profile");
        jdbcTemplate.execute("DROP TABLE IF EXISTS auth_account");

        jdbcTemplate.execute("CREATE TABLE auth_account (user_id UUID PRIMARY KEY, created_at TIMESTAMP NOT NULL)");
        jdbcTemplate.execute("CREATE TABLE user_profile (user_id UUID PRIMARY KEY, display_name VARCHAR(255))");
        jdbcTemplate.execute("CREATE TABLE conversation (conversation_id UUID PRIMARY KEY, type VARCHAR(30) NOT NULL, created_at TIMESTAMP NOT NULL)");
        jdbcTemplate.execute("CREATE TABLE message (message_id UUID PRIMARY KEY, sender_id UUID NOT NULL, message_type VARCHAR(30) NOT NULL, created_at TIMESTAMP NOT NULL)");
        jdbcTemplate.execute("CREATE TABLE moderation_report (report_id UUID PRIMARY KEY, reason_code VARCHAR(50), target_type VARCHAR(30), created_at TIMESTAMP NOT NULL)");
        jdbcTemplate.execute("CREATE TABLE moderation_action (action_id UUID PRIMARY KEY, created_at TIMESTAMP NOT NULL)");
    }

    private void seedData() {
        jdbcTemplate.update(
                "INSERT INTO auth_account(user_id, created_at) VALUES (?, ?), (?, ?), (?, ?)",
                USER_A, ts("2026-03-20 08:00:00"),
                USER_B, ts("2026-03-20 09:00:00"),
                USER_C, ts("2026-03-21 10:00:00")
        );

        jdbcTemplate.update(
                "INSERT INTO user_profile(user_id, display_name) VALUES (?, ?), (?, ?)",
                USER_A, "Alice",
                USER_B, "Bob"
        );

        jdbcTemplate.update(
                "INSERT INTO conversation(conversation_id, type, created_at) VALUES (?, ?, ?), (?, ?, ?), (?, ?, ?)",
                UUID.fromString("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1"), "GROUP", ts("2026-03-20 11:00:00"),
                UUID.fromString("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2"), "DIRECT", ts("2026-03-20 12:00:00"),
                UUID.fromString("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa3"), "GROUP", ts("2026-03-21 12:00:00")
        );

        jdbcTemplate.update(
                "INSERT INTO message(message_id, sender_id, message_type, created_at) VALUES (?, ?, ?, ?), (?, ?, ?, ?), (?, ?, ?, ?), (?, ?, ?, ?)",
                UUID.fromString("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1"), USER_A, "TEXT", ts("2026-03-20 12:30:00"),
                UUID.fromString("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2"), USER_A, "IMAGE", ts("2026-03-20 13:00:00"),
                UUID.fromString("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb3"), USER_A, "TEXT", ts("2026-03-21 09:00:00"),
                UUID.fromString("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb4"), USER_B, "VIDEO", ts("2026-03-21 09:30:00")
        );

        jdbcTemplate.update(
                "INSERT INTO moderation_report(report_id, reason_code, target_type, created_at) VALUES (?, ?, ?, ?), (?, ?, ?, ?), (?, ?, ?, ?)",
                UUID.fromString("cccccccc-cccc-cccc-cccc-ccccccccccc1"), "SPAM", "USER", ts("2026-03-20 14:00:00"),
                UUID.fromString("cccccccc-cccc-cccc-cccc-ccccccccccc2"), "ABUSE", "MESSAGE", ts("2026-03-21 10:00:00"),
                UUID.fromString("cccccccc-cccc-cccc-cccc-ccccccccccc3"), "SPAM", "USER", ts("2026-03-21 11:00:00")
        );

        jdbcTemplate.update(
                "INSERT INTO moderation_action(action_id, created_at) VALUES (?, ?), (?, ?)",
                UUID.fromString("dddddddd-dddd-dddd-dddd-ddddddddddd1"), ts("2026-03-20 15:00:00"),
                UUID.fromString("dddddddd-dddd-dddd-dddd-ddddddddddd2"), ts("2026-03-21 16:00:00")
        );
    }

    private Timestamp ts(String value) {
        return Timestamp.valueOf(value);
    }
}
