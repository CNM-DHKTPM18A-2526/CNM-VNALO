package iuh.cnm.vnalo.analytics_service.validator;

import iuh.cnm.vnalo.analytics_service.exception.ApiException;
import iuh.cnm.vnalo.analytics_service.exception.ErrorCode;
import lombok.NoArgsConstructor;
import org.springframework.stereotype.Component;

import java.time.LocalDate;
import java.time.temporal.ChronoUnit;

/**
 * Validator for date range parameters in analytics endpoints.
 * Enforces: from <= to and range <= 366 days
 */
@Component
@NoArgsConstructor
public class DateRangeValidator {

    private static final int MAX_DATE_RANGE_DAYS = 366;

    /**
     * Validates date range parameters.
     * 
     * @param from Start date (required)
     * @param to   End date (required)
     * @throws ApiException if validation fails
     */
    public void validate(LocalDate from, LocalDate to) {
        if (from == null) {
            throw new ApiException(
                    ErrorCode.ANALYTICS_INVALID_DATE_RANGE,
                    "Missing required parameter: from"
            );
        }
        if (to == null) {
            throw new ApiException(
                    ErrorCode.ANALYTICS_INVALID_DATE_RANGE,
                    "Missing required parameter: to"
            );
        }

        if (from.isAfter(to)) {
            throw new ApiException(
                    ErrorCode.ANALYTICS_INVALID_DATE_RANGE,
                    "from date must be before or equal to to date"
            );
        }

        long daysBetween = ChronoUnit.DAYS.between(from, to);
        if (daysBetween > MAX_DATE_RANGE_DAYS) {
            throw new ApiException(
                    ErrorCode.ANALYTICS_INVALID_DATE_RANGE,
                    String.format("Date range exceeds maximum allowed (%d days)", MAX_DATE_RANGE_DAYS)
            );
        }
    }

    /**
     * Validates and returns the date range or throws exception.
     * Useful for method chaining.
     */
    public DateRange validateAndReturn(LocalDate from, LocalDate to) {
        validate(from, to);
        return new DateRange(from, to);
    }

    /**
     * Simple DTO to represent a validated date range
     */
    public static class DateRange {
        public final LocalDate from;
        public final LocalDate to;

        public DateRange(LocalDate from, LocalDate to) {
            this.from = from;
            this.to = to;
        }

        public long getDaysBetween() {
            return ChronoUnit.DAYS.between(from, to);
        }
    }
}
