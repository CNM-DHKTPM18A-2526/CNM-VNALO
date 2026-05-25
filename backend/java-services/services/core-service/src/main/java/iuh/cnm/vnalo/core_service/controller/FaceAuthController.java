package iuh.cnm.vnalo.core_service.controller;

import ai.onnxruntime.OrtException;
import iuh.cnm.vnalo.core_service.config.FaceAuthProperties;
import iuh.cnm.vnalo.core_service.exception.ApiException;
import iuh.cnm.vnalo.core_service.exception.ErrorCode;
import iuh.cnm.vnalo.core_service.model.dto.response.ApiResponse;
import iuh.cnm.vnalo.core_service.model.dto.response.face.FaceEnrollmentResponse;
import iuh.cnm.vnalo.core_service.model.dto.response.face.FaceStatusResponse;
import iuh.cnm.vnalo.core_service.model.dto.response.face.FaceVerifyResponse;
import iuh.cnm.vnalo.core_service.model.entity.face.FaceEnrollment;
import iuh.cnm.vnalo.core_service.security.UserPrincipal;
import iuh.cnm.vnalo.core_service.service.face.FaceEmbeddingService;
import iuh.cnm.vnalo.core_service.service.face.FaceEnrollmentService;
import iuh.cnm.vnalo.core_service.service.face.FaceImageProcessingService;
import iuh.cnm.vnalo.core_service.service.face.FaceVerificationService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.awt.image.BufferedImage;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;

/**
 * REST controller for face authentication endpoints.
 * Provides enrollment, verification, liveness check, and status operations.
 */
@RestController
@RequestMapping("/face")
@RequiredArgsConstructor
@Slf4j
@Tag(name = "Face Auth", description = "Face authentication endpoints")
public class FaceAuthController {

    private final FaceEnrollmentService enrollmentService;
    private final FaceVerificationService verificationService;
    private final FaceEmbeddingService embeddingService;
    private final FaceImageProcessingService imageProcessing;
    private final FaceAuthProperties faceAuthProperties;

    @PostMapping(value = "/enroll", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @Operation(summary = "Enroll face", description = "Enrolls the user's face for authentication")
    @org.springframework.security.access.prepost.PreAuthorize("isAuthenticated()")
    public ResponseEntity<ApiResponse<FaceEnrollmentResponse>> enrollFace(
            @AuthenticationPrincipal UserPrincipal currentUser,
            @RequestParam("image") MultipartFile image,
            @RequestParam(value = "livenessScore", required = false, defaultValue = "1.0") Double clientLivenessScore,
            @RequestParam(value = "qualityScore", required = false, defaultValue = "1.0") Double clientQualityScore,
            @RequestParam(value = "deviceInfo", required = false) String deviceInfo,
            HttpServletRequest request
    ) throws Exception {
        checkEnabled();
        checkEnrollmentEnabled();

        UUID userId = currentUser.getId();

        float[][][][] embeddingInput = preprocessImage(image, 112);
        double livenessScore = clientLivenessScore != null ? clientLivenessScore : 1.0;
        double qualityScore = clientQualityScore != null ? clientQualityScore : 1.0;

        float[] embedding = extractEmbedding(embeddingInput);

        FaceEnrollment enrollment = enrollmentService.enroll(
                userId, embedding, livenessScore, qualityScore, deviceInfo);

        FaceEnrollmentResponse response = FaceEnrollmentResponse.builder()
                .success(true)
                .enrolledAt(enrollment.getEnrolledAt())
                .livenessScore(enrollment.getLivenessScore() != null
                        ? enrollment.getLivenessScore().doubleValue() : null)
                .version(enrollment.getVersion())
                .build();

        log.info("Face enrolled successfully: userId={}, version={}", userId, enrollment.getVersion());
        return ResponseEntity.ok(ApiResponse.success("Face enrolled successfully", response));
    }

    @PostMapping(value = "/verify", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @Operation(summary = "Verify face", description = "Verifies a face against the enrolled face")
    public ResponseEntity<ApiResponse<FaceVerifyResponse>> verifyFace(
            @RequestParam("image") MultipartFile image,
            @RequestParam("userId") UUID userId,
            @RequestParam(value = "livenessScore", required = false, defaultValue = "1.0") Double clientLivenessScore,
            HttpServletRequest request
    ) throws Exception {
        checkEnabled();
        checkVerificationEnabled();

        float[][][][] embeddingInput = preprocessImage(image, 112);
        float[] probeEmbedding = extractEmbedding(embeddingInput);

        FaceVerificationService.VerificationResult result =
                verificationService.verifyWithEnrollment(
                        userId,
                        probeEmbedding,
                        clientLivenessScore != null ? clientLivenessScore : 1.0,
                        getClientIp(request),
                        request.getHeader("X-Device-Id"),
                        request.getHeader("X-App-Version")
                );

        FaceVerifyResponse response = FaceVerifyResponse.builder()
                .verified(result.verified())
                .confidence(result.confidence())
                .threshold(result.threshold())
                .decision(result.decision())
                .inferenceTimeMs(result.inferenceTimeMs())
                .build();

        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @PostMapping(value = "/liveness-check", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @Operation(summary = "Check liveness", description = "Checks if the face is live (not a spoof)")
    public ResponseEntity<ApiResponse<Map<String, Object>>> checkLiveness(
            @RequestParam("image") MultipartFile image
    ) throws Exception {
        checkEnabled();

        float[][][][] livenessInput = preprocessImage(image, 128);
        double score = embeddingService.checkLiveness(livenessInput);
        double threshold = faceAuthProperties.getLivenessThreshold().doubleValue();
        boolean isLive = score >= threshold;

        Map<String, Object> data = Map.of(
                "isLive", isLive,
                "score", score,
                "threshold", threshold,
                "pass", isLive
        );

        return ResponseEntity.ok(ApiResponse.success(data));
    }

    @GetMapping("/status")
    @Operation(summary = "Get enrollment status", description = "Returns whether the user has enrolled a face")
    @org.springframework.security.access.prepost.PreAuthorize("isAuthenticated()")
    public ResponseEntity<ApiResponse<FaceStatusResponse>> getStatus(
            @AuthenticationPrincipal UserPrincipal currentUser
    ) {
        UUID userId = currentUser.getId();
        var enrollment = enrollmentService.getEnrollment(userId);

        if (enrollment.isEmpty()) {
            FaceStatusResponse response = FaceStatusResponse.builder()
                    .enrolled(false)
                    .build();
            return ResponseEntity.ok(ApiResponse.success(response));
        }

        FaceEnrollment e = enrollment.get();
        FaceStatusResponse response = FaceStatusResponse.builder()
                .enrolled(true)
                .enrolledAt(e.getEnrolledAt())
                .version(e.getVersion())
                .build();

        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @DeleteMapping("/enrollment")
    @Operation(summary = "Delete enrollment", description = "Deletes the user's face enrollment")
    @org.springframework.security.access.prepost.PreAuthorize("isAuthenticated()")
    public ResponseEntity<ApiResponse<Void>> deleteEnrollment(
            @AuthenticationPrincipal UserPrincipal currentUser
    ) {
        UUID userId = currentUser.getId();
        enrollmentService.deleteEnrollment(userId);
        log.info("Face enrollment deleted: userId={}", userId);
        return ResponseEntity.ok(ApiResponse.success("Face enrollment deleted", null));
    }

    @GetMapping("/health")
    @Operation(summary = "Service health", description = "Returns whether face auth service is ready")
    public ResponseEntity<ApiResponse<Map<String, Object>>> health() {
        boolean ready = embeddingService.isReady();
        Map<String, Object> data = Map.of(
                "enabled", faceAuthProperties.isEnabled(),
                "modelReady", ready,
                "timestamp", Instant.now().toString()
        );
        return ResponseEntity.ok(ApiResponse.success(data));
    }

    private float[][][][] preprocessImage(MultipartFile image, int size) throws Exception {
        if (image == null || image.isEmpty()) {
            throw new ApiException(ErrorCode.FACE_NO_FACE_DETECTED);
        }

        BufferedImage img = imageProcessing.decodeImage(image.getBytes());
        if (img == null) {
            throw new ApiException(ErrorCode.FACE_MODEL_ERROR, "Failed to decode image");
        }

        if (size == 112) {
            return imageProcessing.createEmbeddingInput(img);
        } else {
            return imageProcessing.createLivenessInput(img);
        }
    }

    private float[] extractEmbedding(float[][][][] input) throws OrtException {
        if (!embeddingService.isReady()) {
            throw new ApiException(ErrorCode.FACE_SERVICE_UNAVAILABLE);
        }
        try {
            return embeddingService.extractEmbedding(input);
        } catch (OrtException e) {
            log.error("Face embedding extraction failed", e);
            throw new ApiException(ErrorCode.FACE_MODEL_ERROR, "Embedding extraction failed: " + e.getMessage());
        }
    }

    private void checkEnabled() {
        if (!faceAuthProperties.isEnabled()) {
            throw new ApiException(ErrorCode.FACE_SERVICE_UNAVAILABLE);
        }
    }

    private void checkEnrollmentEnabled() {
        if (!faceAuthProperties.isEnrollmentEnabled()) {
            throw new ApiException(ErrorCode.FACE_SERVICE_UNAVAILABLE,
                    "Face enrollment is currently disabled");
        }
    }

    private void checkVerificationEnabled() {
        if (!faceAuthProperties.isVerificationEnabled()) {
            throw new ApiException(ErrorCode.FACE_SERVICE_UNAVAILABLE,
                    "Face verification is currently disabled");
        }
    }

    private String getClientIp(HttpServletRequest request) {
        String xForwarded = request.getHeader("X-Forwarded-For");
        if (xForwarded != null && !xForwarded.isBlank()) {
            return xForwarded.split(",")[0].trim();
        }
        return request.getRemoteAddr();
    }
}
