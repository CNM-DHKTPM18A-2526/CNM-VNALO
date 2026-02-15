package iuh.cnm.vnalo.messagingservice.controller;

import iuh.cnm.vnalo.messagingservice.model.dto.request.call.InitiateCallRequest;
import iuh.cnm.vnalo.messagingservice.model.dto.response.ApiResponse;
import iuh.cnm.vnalo.messagingservice.model.dto.response.call.CallResponse;
import iuh.cnm.vnalo.messagingservice.model.enums.call.CallEndReason;
import iuh.cnm.vnalo.messagingservice.service.CallService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/calls")
@RequiredArgsConstructor
@Tag(name = "Calls", description = "Voice/Video call management APIs")
public class CallController {

    private final CallService callService;

    @PostMapping
    @Operation(summary = "Initiate a new call")
    public ResponseEntity<ApiResponse<CallResponse>> initiateCall(
            @AuthenticationPrincipal UUID currentUserId,
            @Valid @RequestBody InitiateCallRequest request) {
        CallResponse response = callService.initiateCall(currentUserId, request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.success(response));
    }

    @PostMapping("/{callId}/answer")
    @Operation(summary = "Answer an incoming call")
    public ResponseEntity<ApiResponse<CallResponse>> answerCall(
            @AuthenticationPrincipal UUID currentUserId,
            @PathVariable UUID callId) {
        return ResponseEntity.ok(ApiResponse.success(callService.answerCall(callId, currentUserId)));
    }

    @PostMapping("/{callId}/end")
    @Operation(summary = "End a call")
    public ResponseEntity<ApiResponse<CallResponse>> endCall(
            @AuthenticationPrincipal UUID currentUserId,
            @PathVariable UUID callId,
            @RequestParam(defaultValue = "NORMAL") CallEndReason reason) {
        return ResponseEntity.ok(ApiResponse.success(callService.endCall(callId, currentUserId, reason)));
    }

    @PostMapping("/{callId}/decline")
    @Operation(summary = "Decline an incoming call")
    public ResponseEntity<ApiResponse<CallResponse>> declineCall(
            @AuthenticationPrincipal UUID currentUserId,
            @PathVariable UUID callId) {
        return ResponseEntity.ok(ApiResponse.success(callService.declineCall(callId, currentUserId)));
    }

    @GetMapping("/{callId}")
    @Operation(summary = "Get call details")
    public ResponseEntity<ApiResponse<CallResponse>> getCall(
            @AuthenticationPrincipal UUID currentUserId,
            @PathVariable UUID callId) {
        return ResponseEntity.ok(ApiResponse.success(callService.getCall(callId, currentUserId)));
    }

    @GetMapping("/conversations/{conversationId}/history")
    @Operation(summary = "Get call history for a conversation")
    public ResponseEntity<ApiResponse<List<CallResponse>>> getCallHistory(
            @PathVariable UUID conversationId) {
        return ResponseEntity.ok(ApiResponse.success(callService.getCallHistory(conversationId)));
    }
}
