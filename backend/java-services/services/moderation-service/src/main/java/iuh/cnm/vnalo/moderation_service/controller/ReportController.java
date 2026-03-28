package iuh.cnm.vnalo.moderation_service.controller;

import iuh.cnm.vnalo.moderation_service.model.dto.request.CreateReportRequest;
import iuh.cnm.vnalo.moderation_service.model.dto.response.ApiResponse;
import iuh.cnm.vnalo.moderation_service.model.dto.response.ReportResponse;
import iuh.cnm.vnalo.moderation_service.service.ReportService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/reports")
@RequiredArgsConstructor
public class ReportController {

    private final ReportService reportService;

    @PostMapping
    public ResponseEntity<ApiResponse<ReportResponse>> createReport(
            @Valid @RequestBody CreateReportRequest request,
            Authentication authentication
    ) {
        UUID reporterUserId = UUID.fromString(authentication.getName());

        ReportResponse response =
                reportService.createReport(reporterUserId, request);

        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success("Report created successfully", response));
    }

    @GetMapping("/me")
    public ResponseEntity<ApiResponse<Page<ReportResponse>>> getMyReports(
            Authentication authentication,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        UUID reporterUserId = UUID.fromString(authentication.getName());

        Page<ReportResponse> response =
                reportService.getMyReports(reporterUserId, page, size);

        return ResponseEntity.ok(
                ApiResponse.success("Fetched my reports successfully", response)
        );
    }
}