package iuh.cnm.vnalo.moderation_service.query;

import iuh.cnm.vnalo.moderation_service.exception.ApiException;
import iuh.cnm.vnalo.moderation_service.exception.ErrorCode;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;

import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class SharedUserQueryServiceTest {

    @Mock
    private NamedParameterJdbcTemplate jdbcTemplate;

    @InjectMocks
    private SharedUserQueryService sharedUserQueryService;

    @Test
    void getUserSnapshotJson_shouldUseCurrentSchemaJoin() {
        UUID userId = UUID.randomUUID();
        String snapshot = "{\"userId\":\"" + userId + "\"}";

        when(jdbcTemplate.query(any(String.class), any(MapSqlParameterSource.class), any(RowMapper.class)))
                .thenReturn(List.of(snapshot));

        String result = sharedUserQueryService.getUserSnapshotJson(userId);

        assertThat(result).isEqualTo(snapshot);

        ArgumentCaptor<String> sqlCaptor = ArgumentCaptor.forClass(String.class);
        verify(jdbcTemplate).query(sqlCaptor.capture(), any(MapSqlParameterSource.class), any(RowMapper.class));

        String executedSql = sqlCaptor.getValue();
        assertThat(executedSql).contains("JOIN auth_account aa ON aa.id = up.id");
        assertThat(executedSql).contains("WHERE up.id = :userId");
    }

    @Test
    void getUserSnapshotJson_shouldThrowWhenTargetNotFound() {
        when(jdbcTemplate.query(any(String.class), any(MapSqlParameterSource.class), any(RowMapper.class)))
                .thenReturn(List.of());

        assertThatThrownBy(() -> sharedUserQueryService.getUserSnapshotJson(UUID.randomUUID()))
                .isInstanceOf(ApiException.class)
                .extracting(ex -> ((ApiException) ex).getErrorCode())
                .isEqualTo(ErrorCode.MODERATION_TARGET_NOT_FOUND);
    }
}
