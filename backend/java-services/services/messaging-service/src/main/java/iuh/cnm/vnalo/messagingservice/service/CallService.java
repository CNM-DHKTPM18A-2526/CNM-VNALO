package iuh.cnm.vnalo.messagingservice.service;

import iuh.cnm.vnalo.messagingservice.exceptions.ApiException;
import iuh.cnm.vnalo.messagingservice.exceptions.ErrorCode;
import iuh.cnm.vnalo.messagingservice.model.dto.response.call.CallParticipantResponse;
import iuh.cnm.vnalo.messagingservice.model.dto.response.call.CallResponse;
import iuh.cnm.vnalo.messagingservice.model.entity.call.CallParticipant;
import iuh.cnm.vnalo.messagingservice.model.entity.call.CallSession;
import iuh.cnm.vnalo.messagingservice.model.enums.call.*;
import iuh.cnm.vnalo.messagingservice.model.dto.request.call.InitiateCallRequest;
import iuh.cnm.vnalo.messagingservice.repository.call.CallParticipantRepository;
import iuh.cnm.vnalo.messagingservice.repository.call.CallSessionRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
@Transactional
public class CallService {

    private final CallSessionRepository callSessionRepository;
    private final CallParticipantRepository callParticipantRepository;

    public CallResponse initiateCall(UUID currentUserId, InitiateCallRequest request) {
        // Check for existing ongoing call in conversation
        callSessionRepository.findByConversationIdAndStatus(request.getConversationId(), CallStatus.ONGOING)
                .ifPresent(existing -> {
                    throw new ApiException(ErrorCode.CALL_ALREADY_ONGOING);
                });
        callSessionRepository.findByConversationIdAndStatus(request.getConversationId(), CallStatus.RINGING)
                .ifPresent(existing -> {
                    throw new ApiException(ErrorCode.CALL_ALREADY_ONGOING);
                });

        CallSession callSession = CallSession.builder()
                .conversationId(request.getConversationId())
                .callType(request.getCallType())
                .initiatorId(currentUserId)
                .build();
        callSession = callSessionRepository.save(callSession);

        // Add initiator as CALLER
        callParticipantRepository.save(CallParticipant.builder()
                .callId(callSession.getCallId())
                .userId(currentUserId)
                .role(CallParticipantRole.CALLER)
                .status(CallParticipantStatus.CONNECTED)
                .joinedAt(Instant.now())
                .isVideoEnabled(request.getCallType() == CallType.VIDEO || request.getCallType() == CallType.GROUP_VIDEO)
                .isAudioEnabled(true)
                .build());

        // Add other participants as CALLEE with RINGING status
        if (request.getParticipantIds() != null) {
            for (UUID participantId : request.getParticipantIds()) {
                if (!participantId.equals(currentUserId)) {
                    callParticipantRepository.save(CallParticipant.builder()
                            .callId(callSession.getCallId())
                            .userId(participantId)
                            .role(CallParticipantRole.CALLEE)
                            .status(CallParticipantStatus.RINGING)
                            .build());
                }
            }
        }

        return toResponse(callSession);
    }

    public CallResponse answerCall(UUID callId, UUID currentUserId) {
        CallSession callSession = findCallOrThrow(callId);

        CallParticipant participant = callParticipantRepository.findByCallIdAndUserId(callId, currentUserId)
                .orElseThrow(() -> new ApiException(ErrorCode.CALL_NOT_PARTICIPANT));

        participant.setStatus(CallParticipantStatus.CONNECTED);
        participant.setJoinedAt(Instant.now());
        callParticipantRepository.save(participant);

        // If still RINGING, move to ONGOING
        if (callSession.getStatus() == CallStatus.RINGING) {
            callSession.setStatus(CallStatus.ONGOING);
            callSession.setConnectedAt(Instant.now());
            callSessionRepository.save(callSession);
        }

        return toResponse(callSession);
    }

    public CallResponse endCall(UUID callId, UUID currentUserId, CallEndReason reason) {
        CallSession callSession = findCallOrThrow(callId);

        if (callSession.getStatus() == CallStatus.ENDED) {
            throw new ApiException(ErrorCode.CALL_ALREADY_ENDED);
        }

        callSession.setStatus(CallStatus.ENDED);
        callSession.setEndedAt(Instant.now());
        callSession.setEndReason(reason);

        if (callSession.getConnectedAt() != null) {
            long duration = Instant.now().getEpochSecond() - callSession.getConnectedAt().getEpochSecond();
            callSession.setDurationSeconds((int) duration);
        }

        callSessionRepository.save(callSession);

        // Mark all remaining participants as LEFT
        List<CallParticipant> participants = callParticipantRepository.findByCallId(callId);
        for (CallParticipant p : participants) {
            if (p.getStatus() == CallParticipantStatus.CONNECTED || p.getStatus() == CallParticipantStatus.RINGING) {
                p.setStatus(p.getStatus() == CallParticipantStatus.RINGING
                        ? CallParticipantStatus.MISSED : CallParticipantStatus.LEFT);
                p.setLeftAt(Instant.now());
                callParticipantRepository.save(p);
            }
        }

        return toResponse(callSession);
    }

    public CallResponse declineCall(UUID callId, UUID currentUserId) {
        findCallOrThrow(callId);

        CallParticipant participant = callParticipantRepository.findByCallIdAndUserId(callId, currentUserId)
                .orElseThrow(() -> new ApiException(ErrorCode.CALL_NOT_PARTICIPANT));

        participant.setStatus(CallParticipantStatus.DECLINED);
        participant.setLeftAt(Instant.now());
        callParticipantRepository.save(participant);

        return getCall(callId, currentUserId);
    }

    @Transactional(readOnly = true)
    public CallResponse getCall(UUID callId, UUID currentUserId) {
        CallSession callSession = findCallOrThrow(callId);
        return toResponse(callSession);
    }

    @Transactional(readOnly = true)
    public List<CallResponse> getCallHistory(UUID conversationId) {
        return callSessionRepository.findByConversationIdOrderByStartedAtDesc(conversationId).stream()
                .map(this::toResponse)
                .toList();
    }

    // --- Helper Methods ---

    private CallSession findCallOrThrow(UUID callId) {
        return callSessionRepository.findById(callId)
                .orElseThrow(() -> new ApiException(ErrorCode.CALL_NOT_FOUND));
    }

    private CallResponse toResponse(CallSession session) {
        List<CallParticipantResponse> participants = callParticipantRepository.findByCallId(session.getCallId())
                .stream().map(this::toParticipantResponse).toList();

        return CallResponse.builder()
                .callId(session.getCallId())
                .conversationId(session.getConversationId())
                .callType(session.getCallType())
                .initiatorId(session.getInitiatorId())
                .status(session.getStatus())
                .startedAt(session.getStartedAt())
                .connectedAt(session.getConnectedAt())
                .endedAt(session.getEndedAt())
                .durationSeconds(session.getDurationSeconds())
                .endReason(session.getEndReason() != null ? session.getEndReason().name() : null)
                .participants(participants)
                .build();
    }

    private CallParticipantResponse toParticipantResponse(CallParticipant p) {
        return CallParticipantResponse.builder()
                .userId(p.getUserId())
                .role(p.getRole().name())
                .status(p.getStatus().name())
                .joinedAt(p.getJoinedAt())
                .leftAt(p.getLeftAt())
                .isVideoEnabled(p.getIsVideoEnabled())
                .isAudioEnabled(p.getIsAudioEnabled())
                .isScreenSharing(p.getIsScreenSharing())
                .build();
    }
}
