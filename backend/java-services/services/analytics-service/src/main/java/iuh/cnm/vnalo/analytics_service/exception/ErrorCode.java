package iuh.cnm.vnalo.analytics_service.exception;

import lombok.Getter;
import lombok.RequiredArgsConstructor;

@Getter
@RequiredArgsConstructor
public enum ErrorCode {
    // Analytics - Access & Security
    ANALYTICS_FORBIDDEN("ANA_001", "Access forbidden"),
    
    // Analytics - Validation
    ANALYTICS_INVALID_DATE_RANGE("ANA_002", "Invalid date range"),
    ANALYTICS_MISSING_PARAMETER("ANA_002_A", "Missing required parameter"),
    ANALYTICS_DATE_RANGE_TOO_LARGE("ANA_002_B", "Date range exceeds maximum allowed"),
    
    // Analytics - Business Logic
    ANALYTICS_EVENT_INGESTION_FAILED("ANA_003", "Event ingestion failed");

    private final String code;
    private final String message;
}