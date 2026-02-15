package iuh.cnm.vnalo.messagingservice.service;

import iuh.cnm.vnalo.messagingservice.exceptions.ApiException;
import iuh.cnm.vnalo.messagingservice.exceptions.ErrorCode;
import iuh.cnm.vnalo.messagingservice.model.dto.request.conversation.CreateConversationRequest;
import iuh.cnm.vnalo.messagingservice.model.dto.request.conversation.UpdateConversationRequest;
import iuh.cnm.vnalo.messagingservice.model.dto.response.conversation.ConversationMemberResponse;
import iuh.cnm.vnalo.messagingservice.model.dto.response.conversation.ConversationResponse;
import iuh.cnm.vnalo.messagingservice.model.entity.conversation.*;
import iuh.cnm.vnalo.messagingservice.model.enums.conversation.ConversationType;
import iuh.cnm.vnalo.messagingservice.model.enums.conversation.JoinMode;
import iuh.cnm.vnalo.messagingservice.model.enums.conversation.JoinRequestStatus;
import iuh.cnm.vnalo.messagingservice.model.enums.conversation.MemberRole;
import iuh.cnm.vnalo.messagingservice.repository.conversation.*;
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
public class ConversationService {

    private final ConversationRepository conversationRepository;
    private final ConversationMemberRepository memberRepository;
    private final ConversationDirectMapRepository directMapRepository;
    private final ConversationInboxRepository inboxRepository;
    private final GroupBannedMemberRepository bannedMemberRepository;
    private final GroupJoinRequestRepository joinRequestRepository;

    public ConversationResponse createConversation(UUID currentUserId, CreateConversationRequest request) {
        if (request.getType() == ConversationType.DIRECT) {
            return createDirectConversation(currentUserId, request);
        }
        return createGroupConversation(currentUserId, request);
    }

    private ConversationResponse createDirectConversation(UUID currentUserId, CreateConversationRequest request) {
        if (request.getMemberIds().size() != 1) {
            throw new ApiException(ErrorCode.VALIDATION_ERROR, "Direct conversation requires exactly 1 other member");
        }
        UUID otherUserId = request.getMemberIds().get(0);

        // Ensure ordered user IDs for direct map lookup
        UUID userId1 = currentUserId.compareTo(otherUserId) < 0 ? currentUserId : otherUserId;
        UUID userId2 = currentUserId.compareTo(otherUserId) < 0 ? otherUserId : currentUserId;

        directMapRepository.findByUserId1AndUserId2(userId1, userId2)
                .ifPresent(existing -> {
                    throw new ApiException(ErrorCode.CONV_DIRECT_ALREADY_EXISTS);
                });

        Conversation conversation = Conversation.builder()
                .type(ConversationType.DIRECT)
                .createdBy(currentUserId)
                .build();
        conversation = conversationRepository.save(conversation);

        // Add both members
        addMember(conversation.getConversationId(), currentUserId, MemberRole.MEMBER, currentUserId);
        addMember(conversation.getConversationId(), otherUserId, MemberRole.MEMBER, currentUserId);

        // Save direct map
        directMapRepository.save(ConversationDirectMap.builder()
                .userId1(userId1)
                .userId2(userId2)
                .conversationId(conversation.getConversationId())
                .build());

        return toResponse(conversation);
    }

    private ConversationResponse createGroupConversation(UUID currentUserId, CreateConversationRequest request) {
        Conversation conversation = Conversation.builder()
                .type(ConversationType.GROUP)
                .title(request.getTitle())
                .avatarUrl(request.getAvatarUrl())
                .description(request.getDescription())
                .createdBy(currentUserId)
                .build();
        conversation = conversationRepository.save(conversation);

        // Add creator as owner
        addMember(conversation.getConversationId(), currentUserId, MemberRole.OWNER, currentUserId);

        // Add other members
        for (UUID memberId : request.getMemberIds()) {
            if (!memberId.equals(currentUserId)) {
                addMember(conversation.getConversationId(), memberId, MemberRole.MEMBER, currentUserId);
            }
        }

        return toResponse(conversation);
    }

    @Transactional(readOnly = true)
    public ConversationResponse getConversation(UUID conversationId, UUID currentUserId) {
        Conversation conversation = findConversationOrThrow(conversationId);
        validateMembership(conversationId, currentUserId);
        return toResponse(conversation);
    }

    public ConversationResponse updateConversation(UUID conversationId, UUID currentUserId,
                                                    UpdateConversationRequest request) {
        Conversation conversation = findConversationOrThrow(conversationId);
        validateAdminPermission(conversationId, currentUserId);

        if (request.getTitle() != null) conversation.setTitle(request.getTitle());
        if (request.getAvatarUrl() != null) conversation.setAvatarUrl(request.getAvatarUrl());
        if (request.getDescription() != null) conversation.setDescription(request.getDescription());
        if (request.getJoinMode() != null) conversation.setJoinMode(request.getJoinMode());
        if (request.getMemberLimit() != null) conversation.setMemberLimit(request.getMemberLimit());
        if (request.getAllowMemberInvite() != null) conversation.setAllowMemberInvite(request.getAllowMemberInvite());
        if (request.getAllowMemberPin() != null) conversation.setAllowMemberPin(request.getAllowMemberPin());
        if (request.getAllowMemberEditInfo() != null) conversation.setAllowMemberEditInfo(request.getAllowMemberEditInfo());

        return toResponse(conversationRepository.save(conversation));
    }

    public void addMembers(UUID conversationId, UUID currentUserId, List<UUID> userIds) {
        Conversation conversation = findConversationOrThrow(conversationId);
        validateMembership(conversationId, currentUserId);

        // Check permissions
        ConversationMember currentMember = memberRepository.findByConversationIdAndUserId(conversationId, currentUserId)
                .orElseThrow(() -> new ApiException(ErrorCode.CONV_NOT_MEMBER));
        
        boolean isAdminOrOwner = currentMember.getRole() == MemberRole.ADMIN || currentMember.getRole() == MemberRole.OWNER;
        
        if (!isAdminOrOwner && !Boolean.TRUE.equals(conversation.getAllowMemberInvite())) {
            throw new ApiException(ErrorCode.CONV_INSUFFICIENT_PERMISSION);
        }

        long currentCount = memberRepository.countByConversationIdAndLeftAtIsNull(conversationId);

        for (UUID userId : userIds) {
            if (currentCount >= conversation.getMemberLimit()) {
                throw new ApiException(ErrorCode.CONV_MEMBER_LIMIT_REACHED);
            }
            if (!memberRepository.existsByConversationIdAndUserIdAndLeftAtIsNull(conversationId, userId)) {
                addMember(conversationId, userId, MemberRole.MEMBER, currentUserId);
                currentCount++;
            }
        }
    }

    public void removeMember(UUID conversationId, UUID currentUserId, UUID memberUserId) {
        validateAdminPermission(conversationId, currentUserId);

        ConversationMember member = memberRepository.findByConversationIdAndUserId(conversationId, memberUserId)
                .orElseThrow(() -> new ApiException(ErrorCode.CONV_NOT_MEMBER));

        member.setLeftAt(Instant.now());
        member.setRemovedBy(currentUserId);
        memberRepository.save(member);
    }

    public void leaveConversation(UUID conversationId, UUID currentUserId) {
        ConversationMember member = memberRepository.findByConversationIdAndUserId(conversationId, currentUserId)
                .orElseThrow(() -> new ApiException(ErrorCode.CONV_NOT_MEMBER));

        if (member.getRole() == MemberRole.OWNER) {
            throw new ApiException(ErrorCode.CONV_CANNOT_LEAVE_OWNER);
        }

        member.setLeftAt(Instant.now());
        memberRepository.save(member);
    }

    public void updateMemberRole(UUID conversationId, UUID currentUserId, UUID targetUserId, MemberRole newRole) {
        validateAdminPermission(conversationId, currentUserId);
        
        ConversationMember currentMember = memberRepository.findByConversationIdAndUserId(conversationId, currentUserId)
                .orElseThrow(() -> new ApiException(ErrorCode.CONV_NOT_MEMBER));
        
        ConversationMember targetMember = memberRepository.findByConversationIdAndUserId(conversationId, targetUserId)
                .orElseThrow(() -> new ApiException(ErrorCode.CONV_NOT_MEMBER));

        // Validation Logic
        if (currentMember.getRole() == MemberRole.ADMIN && (targetMember.getRole() == MemberRole.ADMIN || targetMember.getRole() == MemberRole.OWNER)) {
             throw new ApiException(ErrorCode.CONV_INSUFFICIENT_PERMISSION);
        }
        
        if (newRole == MemberRole.OWNER) {
            if (currentMember.getRole() != MemberRole.OWNER) {
                 throw new ApiException(ErrorCode.CONV_INSUFFICIENT_PERMISSION);
            }
            // Transfer ownership: Current Owner -> Admin, Target -> Owner
            currentMember.setRole(MemberRole.ADMIN);
            memberRepository.save(currentMember);
        }
        
        targetMember.setRole(newRole);
        memberRepository.save(targetMember);
    }

    @Transactional(readOnly = true)
    public List<ConversationMemberResponse> getMembers(UUID conversationId, UUID currentUserId) {
        validateMembership(conversationId, currentUserId);
        return memberRepository.findByConversationIdAndLeftAtIsNull(conversationId).stream()
                .map(this::toMemberResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<iuh.cnm.vnalo.messagingservice.model.dto.response.conversation.ConversationInboxResponse> getConversations(UUID currentUserId) {
        List<ConversationInbox> inboxList = inboxRepository.findByUserIdAndIsHiddenFalseOrderByLastMessageAtDesc(currentUserId);
        
        List<UUID> conversationIds = inboxList.stream().map(ConversationInbox::getConversationId).toList();
        List<Conversation> conversations = conversationRepository.findAllById(conversationIds);
        java.util.Map<UUID, Conversation> conversationMap = conversations.stream()
                .collect(java.util.stream.Collectors.toMap(Conversation::getConversationId, c -> c));

        return inboxList.stream().map(inbox -> {
            Conversation conversation = conversationMap.get(inbox.getConversationId());
            if (conversation == null) return null;

            // For DIRECT conversations, find the other member's userId
            UUID otherMemberId = null;
            if (conversation.getType() == ConversationType.DIRECT) {
                otherMemberId = memberRepository.findByConversationIdAndLeftAtIsNull(inbox.getConversationId())
                        .stream()
                        .map(ConversationMember::getUserId)
                        .filter(uid -> !uid.equals(currentUserId))
                        .findFirst()
                        .orElse(null);
            }

            return iuh.cnm.vnalo.messagingservice.model.dto.response.conversation.ConversationInboxResponse.builder()
                    .conversationId(inbox.getConversationId())
                    .title(conversation.getTitle())
                    .avatarUrl(conversation.getAvatarUrl())
                    .type(conversation.getType().name())
                    .lastMessagePreview(inbox.getLastMessagePreview())
                    .lastMessageSenderId(inbox.getLastMessageSenderId())
                    .lastMessageType(inbox.getLastMessageType())
                    .lastMessageAt(inbox.getLastMessageAt())
                    .unreadCount(inbox.getUnreadCount())
                    .isPinned(inbox.getIsPinned())
                    .isMuted(inbox.getIsMuted())
                    .otherMemberId(otherMemberId)
                    .build();
        }).filter(java.util.Objects::nonNull).toList();
    }

    // --- Ban Management ---

    public void banMember(UUID conversationId, UUID currentUserId, UUID targetUserId,
                          String reason, Instant expiresAt) {
        Conversation conversation = findConversationOrThrow(conversationId);
        if (conversation.getType() != ConversationType.GROUP) {
            throw new ApiException(ErrorCode.CONV_NOT_GROUP);
        }
        validateAdminPermission(conversationId, currentUserId);

        if (bannedMemberRepository.existsByConversationIdAndUserId(conversationId, targetUserId)) {
            throw new ApiException(ErrorCode.CONV_USER_BANNED);
        }

        // Remove from conversation if currently a member
        memberRepository.findByConversationIdAndUserId(conversationId, targetUserId)
                .ifPresent(member -> {
                    member.setLeftAt(Instant.now());
                    memberRepository.save(member);
                });

        bannedMemberRepository.save(GroupBannedMember.builder()
                .conversationId(conversationId)
                .userId(targetUserId)
                .bannedBy(currentUserId)
                .reason(reason)
                .expiresAt(expiresAt)
                .build());

        log.info("User {} banned from conversation {} by {}", targetUserId, conversationId, currentUserId);
    }

    public void unbanMember(UUID conversationId, UUID currentUserId, UUID targetUserId) {
        findConversationOrThrow(conversationId);
        validateAdminPermission(conversationId, currentUserId);

        if (!bannedMemberRepository.existsByConversationIdAndUserId(conversationId, targetUserId)) {
            throw new ApiException(ErrorCode.CONV_USER_NOT_BANNED);
        }

        bannedMemberRepository.deleteByConversationIdAndUserId(conversationId, targetUserId);
        log.info("User {} unbanned from conversation {} by {}", targetUserId, conversationId, currentUserId);
    }

    @Transactional(readOnly = true)
    public List<GroupBannedMember> getBannedMembers(UUID conversationId, UUID currentUserId) {
        findConversationOrThrow(conversationId);
        validateAdminPermission(conversationId, currentUserId);
        return bannedMemberRepository.findByConversationId(conversationId);
    }

    // --- Join Request Management ---

    public GroupJoinRequest requestToJoin(UUID conversationId, UUID currentUserId, String message) {
        Conversation conversation = findConversationOrThrow(conversationId);
        if (conversation.getType() != ConversationType.GROUP) {
            throw new ApiException(ErrorCode.CONV_NOT_GROUP);
        }

        // Check if already a member
        if (memberRepository.existsByConversationIdAndUserIdAndLeftAtIsNull(conversationId, currentUserId)) {
            throw new ApiException(ErrorCode.CONV_ALREADY_MEMBER);
        }

        // Check if banned
        if (bannedMemberRepository.existsByConversationIdAndUserId(conversationId, currentUserId)) {
            throw new ApiException(ErrorCode.CONV_USER_BANNED);
        }

        // Check duplicate pending request
        if (joinRequestRepository.existsByConversationIdAndUserIdAndStatus(
                conversationId, currentUserId, JoinRequestStatus.PENDING)) {
            throw new ApiException(ErrorCode.CONV_JOIN_REQUEST_ALREADY_PENDING);
        }

        // If join mode is OPEN, auto-approve
        if (conversation.getJoinMode() == JoinMode.OPEN) {
            addMember(conversationId, currentUserId, MemberRole.MEMBER, currentUserId);
            return GroupJoinRequest.builder()
                    .conversationId(conversationId)
                    .userId(currentUserId)
                    .message(message)
                    .status(JoinRequestStatus.APPROVED)
                    .reviewedAt(Instant.now())
                    .build();
        }

        return joinRequestRepository.save(GroupJoinRequest.builder()
                .conversationId(conversationId)
                .userId(currentUserId)
                .message(message)
                .build());
    }

    public void approveJoinRequest(UUID requestId, UUID currentUserId) {
        GroupJoinRequest request = joinRequestRepository.findById(requestId)
                .orElseThrow(() -> new ApiException(ErrorCode.CONV_JOIN_REQUEST_NOT_FOUND));

        validateAdminPermission(request.getConversationId(), currentUserId);

        if (request.getStatus() != JoinRequestStatus.PENDING) {
            throw new ApiException(ErrorCode.CONV_JOIN_REQUEST_NOT_FOUND);
        }

        request.setStatus(JoinRequestStatus.APPROVED);
        request.setReviewedBy(currentUserId);
        request.setReviewedAt(Instant.now());
        joinRequestRepository.save(request);

        // Add as member
        addMember(request.getConversationId(), request.getUserId(), MemberRole.MEMBER, currentUserId);
        log.info("Join request {} approved by {}", requestId, currentUserId);
    }

    public void rejectJoinRequest(UUID requestId, UUID currentUserId) {
        GroupJoinRequest request = joinRequestRepository.findById(requestId)
                .orElseThrow(() -> new ApiException(ErrorCode.CONV_JOIN_REQUEST_NOT_FOUND));

        validateAdminPermission(request.getConversationId(), currentUserId);

        if (request.getStatus() != JoinRequestStatus.PENDING) {
            throw new ApiException(ErrorCode.CONV_JOIN_REQUEST_NOT_FOUND);
        }

        request.setStatus(JoinRequestStatus.REJECTED);
        request.setReviewedBy(currentUserId);
        request.setReviewedAt(Instant.now());
        joinRequestRepository.save(request);
        log.info("Join request {} rejected by {}", requestId, currentUserId);
    }

    @Transactional(readOnly = true)
    public List<GroupJoinRequest> getPendingJoinRequests(UUID conversationId, UUID currentUserId) {
        findConversationOrThrow(conversationId);
        validateAdminPermission(conversationId, currentUserId);
        return joinRequestRepository.findByConversationIdAndStatus(conversationId, JoinRequestStatus.PENDING);
    }

    // --- Helper Methods ---

    private void addMember(UUID conversationId, UUID userId, MemberRole role, UUID joinedBy) {
        memberRepository.save(ConversationMember.builder()
                .conversationId(conversationId)
                .userId(userId)
                .role(role)
                .joinedBy(joinedBy)
                .build());
    }

    private Conversation findConversationOrThrow(UUID conversationId) {
        return conversationRepository.findById(conversationId)
                .orElseThrow(() -> new ApiException(ErrorCode.CONV_NOT_FOUND));
    }

    private void validateMembership(UUID conversationId, UUID userId) {
        if (!memberRepository.existsByConversationIdAndUserIdAndLeftAtIsNull(conversationId, userId)) {
            throw new ApiException(ErrorCode.CONV_NOT_MEMBER);
        }
    }

    private void validateAdminPermission(UUID conversationId, UUID userId) {
        ConversationMember member = memberRepository.findByConversationIdAndUserId(conversationId, userId)
                .orElseThrow(() -> new ApiException(ErrorCode.CONV_NOT_MEMBER));

        if (member.getRole() != MemberRole.OWNER && member.getRole() != MemberRole.ADMIN) {
            throw new ApiException(ErrorCode.CONV_INSUFFICIENT_PERMISSION);
        }
    }

    private ConversationResponse toResponse(Conversation c) {
        return ConversationResponse.builder()
                .conversationId(c.getConversationId())
                .type(c.getType())
                .title(c.getTitle())
                .avatarUrl(c.getAvatarUrl())
                .description(c.getDescription())
                .status(c.getStatus())
                .createdBy(c.getCreatedBy())
                .memberLimit(c.getMemberLimit())
                .createdAt(c.getCreatedAt())
                .updatedAt(c.getUpdatedAt())
                .build();
    }

    private ConversationMemberResponse toMemberResponse(ConversationMember m) {
        return ConversationMemberResponse.builder()
                .userId(m.getUserId())
                .role(m.getRole())
                .nickname(m.getNickname())
                .joinedAt(m.getJoinedAt())
                .build();
    }
}

