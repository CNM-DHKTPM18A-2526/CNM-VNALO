package iuh.cnm.vnalo.messagingservice.service;

import iuh.cnm.vnalo.messagingservice.exceptions.ApiException;
import iuh.cnm.vnalo.messagingservice.exceptions.ErrorCode;
import iuh.cnm.vnalo.messagingservice.model.dto.request.message.SendMessageRequest;
import iuh.cnm.vnalo.messagingservice.model.dto.response.message.MessageResponse;
import iuh.cnm.vnalo.messagingservice.model.entity.conversation.ConversationInbox;
import iuh.cnm.vnalo.messagingservice.model.entity.message.Message;
import iuh.cnm.vnalo.messagingservice.model.enums.message.MessageStatus;
import iuh.cnm.vnalo.messagingservice.model.enums.message.MessageType;
import iuh.cnm.vnalo.messagingservice.repository.conversation.ConversationInboxRepository;
import iuh.cnm.vnalo.messagingservice.repository.conversation.ConversationMemberRepository;
import iuh.cnm.vnalo.messagingservice.repository.conversation.ConversationRepository;
import iuh.cnm.vnalo.messagingservice.repository.message.MessageRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Slice;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class MessageService {

    private final MessageRepository messageRepository;
    private final ConversationRepository conversationRepository;
    private final ConversationMemberRepository memberRepository;
    private final ConversationInboxRepository inboxRepository;
    private final WebSocketEventService webSocketEventService;

    public MessageResponse sendMessage(UUID currentUserId, SendMessageRequest request) {
        // Validate conversation exists (PostgreSQL)
        if (!conversationRepository.existsById(request.getConversationId())) {
            throw new ApiException(ErrorCode.CONV_NOT_FOUND);
        }

        // Validate membership (PostgreSQL)
        if (!memberRepository.existsByConversationIdAndUserIdAndLeftAtIsNull(request.getConversationId(), currentUserId)) {
            throw new ApiException(ErrorCode.CONV_NOT_MEMBER);
        }

        // Build and save message (Cassandra)
        Message message = Message.builder()
                .conversationId(request.getConversationId())
                .senderId(currentUserId)
                .type(request.getType().name())
                .content(request.getContent())
                .replyToMessageId(request.getReplyToMessageId())
                .attachments(request.getAttachments())
                .status(MessageStatus.SENT.name())
                .build();

        message = messageRepository.save(message);

        // Update Inbox for all members (PostgreSQL, @Transactional handled by inboxRepository)
        updateInboxForMembers(message);

        MessageResponse response = toResponse(message);

        // Push real-time event via WebSocket
        webSocketEventService.sendToConversation(
                message.getConversationId(), "NEW_MESSAGE", response);

        return response;
    }

    public Slice<MessageResponse> getMessages(UUID conversationId, UUID currentUserId, Pageable pageable) {
        // Validate membership (PostgreSQL)
        if (!memberRepository.existsByConversationIdAndUserIdAndLeftAtIsNull(conversationId, currentUserId)) {
            throw new ApiException(ErrorCode.CONV_NOT_MEMBER);
        }

        // Query Cassandra — already sorted by created_at DESC via clustering order
        return messageRepository.findByConversationId(conversationId, pageable)
                .map(this::toResponse);
    }

    public void deleteMessage(UUID conversationId, UUID messageId, UUID currentUserId) {
        Message message = messageRepository.findByConversationIdAndMessageId(conversationId, messageId)
                .orElseThrow(() -> new ApiException(ErrorCode.MSG_NOT_FOUND));

        if (!message.getSenderId().equals(currentUserId)) {
            throw new ApiException(ErrorCode.MSG_NOT_SENDER);
        }

        if (message.getIsDeleted()) {
            throw new ApiException(ErrorCode.MSG_ALREADY_DELETED);
        }

        message.setIsDeleted(true);
        messageRepository.save(message);
    }

    @Transactional
    private void updateInboxForMembers(Message message) {
        memberRepository.findByConversationIdAndLeftAtIsNull(message.getConversationId())
            .forEach(member -> {
                 ConversationInbox inbox = inboxRepository.findById(new ConversationInbox.InboxId(member.getUserId(), message.getConversationId()))
                        .orElse(ConversationInbox.builder()
                                .userId(member.getUserId())
                                .conversationId(message.getConversationId())
                                .build());

                 inbox.setLastMessageAt(message.getCreatedAt());
                 inbox.setLastMessagePreview(previewContent(message));
                 inbox.setLastMessageSenderId(message.getSenderId());
                 inbox.setLastMessageType(message.getType());
                 inbox.setUpdatedAt(Instant.now());

                 if (!member.getUserId().equals(message.getSenderId())) {
                     inbox.setUnreadCount(inbox.getUnreadCount() + 1);
                 }

                 inboxRepository.save(inbox);
            });
    }

    private String previewContent(Message message) {
        MessageType type = message.getTypeEnum();
        return switch (type) {
            case TEXT -> message.getContent().length() > 50 ? message.getContent().substring(0, 47) + "..." : message.getContent();
            case IMAGE -> "[Image]";
            case VIDEO -> "[Video]";
            case FILE -> "[File]";
            case STICKER -> "[Sticker]";
            case VOICE -> "[Voice]";
            case LOCATION -> "[Location]";
            case CONTACT -> "[Contact]";
             default -> "[Message]";
        };
    }

    private MessageResponse toResponse(Message m) {
        return MessageResponse.builder()
                .messageId(m.getMessageId())
                .conversationId(m.getConversationId())
                .senderId(m.getSenderId())
                .type(m.getTypeEnum())
                .content(m.getContent())
                .replyToMessageId(m.getReplyToMessageId())
                .attachments(m.getAttachments())
                .status(m.getStatusEnum())
                .isDeleted(m.getIsDeleted())
                .createdAt(m.getCreatedAt())
                .build();
    }
}
