package iuh.cnm.vnalo.messagingservice.service;

import iuh.cnm.vnalo.messagingservice.exceptions.ApiException;
import iuh.cnm.vnalo.messagingservice.exceptions.ErrorCode;
import iuh.cnm.vnalo.messagingservice.model.entity.MessageReaction;
import iuh.cnm.vnalo.messagingservice.model.entity.PinnedMsg;
import iuh.cnm.vnalo.messagingservice.model.entity.Poll;
import iuh.cnm.vnalo.messagingservice.model.entity.PollOption;
import iuh.cnm.vnalo.messagingservice.model.entity.PollVote;
import iuh.cnm.vnalo.messagingservice.repository.message.MessageReactionRepository;
import iuh.cnm.vnalo.messagingservice.repository.message.PinnedMessageRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
@Transactional
public class MessageMetadataService {

    private final iuh.cnm.vnalo.messagingservice.repository.message.PollRepository pollRepository;
    private final iuh.cnm.vnalo.messagingservice.repository.message.PollOptionRepository pollOptionRepository;
    private final iuh.cnm.vnalo.messagingservice.repository.message.PollVoteRepository pollVoteRepository;
    private final MessageReactionRepository reactionRepository;
    private final PinnedMessageRepository pinnedMessageRepository;

    // --- Reactions ---

    public MessageReaction addReaction(UUID conversationId, UUID messageId, UUID userId, String emoji) {
        if (reactionRepository.existsByMessageIdAndUserId(messageId, userId)) {
            throw new ApiException(ErrorCode.REACTION_ALREADY_EXISTS);
        }

        MessageReaction reaction = MessageReaction.builder()
                .conversationId(conversationId)
                .messageId(messageId)
                .serverSeq(0L) // Will be set by event processing
                .userId(userId)
                .emoji(emoji)
                .build();

        return reactionRepository.save(reaction);
    }

    public void removeReaction(UUID messageId, UUID userId) {
        MessageReaction reaction = reactionRepository.findByMessageIdAndUserId(messageId, userId)
                .orElseThrow(() -> new ApiException(ErrorCode.REACTION_NOT_FOUND));
        reactionRepository.delete(reaction);
    }

    @Transactional(readOnly = true)
    public List<MessageReaction> getReactions(UUID messageId) {
        return reactionRepository.findByMessageId(messageId);
    }

    // --- Pinned Messages ---
    // --- Pinned Messages ---

    public PinnedMsg pinMessage(UUID conversationId, UUID messageId, Long serverSeq, UUID pinnedBy) {
        if (pinnedMessageRepository.existsByConversationIdAndMessageId(conversationId, messageId)) {
            throw new ApiException(ErrorCode.MSG_ALREADY_PINNED);
        }

        PinnedMsg pinned = PinnedMsg.builder()
                .conversationId(conversationId)
                .messageId(messageId)
                .serverSeq(serverSeq)
                .pinnedBy(pinnedBy)
                .build();

        return pinnedMessageRepository.save(pinned);
    }

    public void unpinMessage(UUID conversationId, UUID messageId) {
        PinnedMsg pinned = pinnedMessageRepository.findByConversationIdAndMessageId(conversationId, messageId)
                .orElseThrow(() -> new ApiException(ErrorCode.MSG_NOT_PINNED));
        pinnedMessageRepository.delete(pinned);
    }

    @Transactional(readOnly = true)
    public List<PinnedMsg> getPinnedMessages(UUID conversationId) {
        return pinnedMessageRepository.findByConversationIdOrderByPinnedAtDesc(conversationId);
    }

    // --- Polls ---

    public iuh.cnm.vnalo.messagingservice.model.dto.response.message.PollResponse createPoll(
            UUID conversationId, UUID creatorId, 
            iuh.cnm.vnalo.messagingservice.model.dto.request.message.CreatePollRequest request) {
        
        // Note: Ideally, check conversation membership here.

        Poll poll = Poll.builder()
                .conversationId(conversationId)
                .messageId(UUID.randomUUID()) // Poll is linked to a message, or IS the message content? 
                                              // In this schema, Poll has a separate messageId field. 
                                              // Usually you create a Message FIRST, then Poll.
                                              // But here we are creating a Poll directly. 
                                              // Let's assume we generate a placeholder ID or the caller should provide it.
                                              // For now, generating random UUID.
                .creatorId(creatorId)
                .question(request.getQuestion())
                .allowMultiple(request.getAllowMultipleVotes())
                .expiresAt(request.getExpiresAt() != null ? request.getExpiresAt().toInstant(java.time.ZoneOffset.UTC) : null)
                .status(iuh.cnm.vnalo.messagingservice.model.enums.message.PollStatus.ACTIVE)
                .build();
        
        poll = pollRepository.save(poll);

        int order = 0;
        for (String optionText : request.getOptions()) {
            PollOption option = PollOption.builder()
                    .pollId(poll.getPollId())
                    .text(optionText)
                    .createdBy(creatorId)
                    .optionOrder(order++)
                    .voteCount(0)
                    .build();
            pollOptionRepository.save(option);
        }

        return getPoll(poll.getPollId(), creatorId);
    }

    public void vote(UUID pollId, UUID userId, iuh.cnm.vnalo.messagingservice.model.dto.request.message.VotePollRequest request) {
        Poll poll = pollRepository.findById(pollId)
                .orElseThrow(() -> new ApiException(ErrorCode.VALIDATION_ERROR, "Poll not found"));

        if (poll.getStatus() == iuh.cnm.vnalo.messagingservice.model.enums.message.PollStatus.CLOSED) {
            throw new ApiException(ErrorCode.VALIDATION_ERROR, "Poll is closed");
        }

        if (poll.getExpiresAt() != null && java.time.Instant.now().isAfter(poll.getExpiresAt())) {
             poll.setStatus(iuh.cnm.vnalo.messagingservice.model.enums.message.PollStatus.CLOSED);
             pollRepository.save(poll);
             throw new ApiException(ErrorCode.VALIDATION_ERROR, "Poll has expired");
        }

        // Remove existing votes if not allow multiple
        // Actually, if allowMultiple=false, we should clear previous votes or reject?
        // Usually, voting again toggles or replaces.
        // Let's implement: clear previous votes for this user, then add new ones.
        
        List<PollVote> existingVotes = pollVoteRepository.findByPollId(pollId).stream()
                .filter(v -> v.getUserId().equals(userId)).toList();
        
        for (PollVote v : existingVotes) {
            pollVoteRepository.delete(v);
            // Decrement count
            PollOption option = pollOptionRepository.findById(v.getOptionId()).orElse(null);
            if (option != null) {
                option.setVoteCount(Math.max(0, option.getVoteCount() - 1));
                pollOptionRepository.save(option);
            }
        }

        if (!Boolean.TRUE.equals(poll.getAllowMultiple()) && request.getOptionIds().size() > 1) {
             throw new ApiException(ErrorCode.VALIDATION_ERROR, "Multiple votes not allowed");
        }

        for (UUID optionId : request.getOptionIds()) {
            PollOption option = pollOptionRepository.findById(optionId)
                    .orElseThrow(() -> new ApiException(ErrorCode.VALIDATION_ERROR, "Option not found"));
            
            if (!option.getPollId().equals(pollId)) {
                 throw new ApiException(ErrorCode.VALIDATION_ERROR, "Invalid option for this poll");
            }

            PollVote vote = PollVote.builder()
                    .pollId(pollId)
                    .optionId(optionId)
                    .userId(userId)
                    .build();
            pollVoteRepository.save(vote);

            option.setVoteCount(option.getVoteCount() + 1);
            pollOptionRepository.save(option);
        }
    }

    @Transactional(readOnly = true)
    public iuh.cnm.vnalo.messagingservice.model.dto.response.message.PollResponse getPoll(UUID pollId, UUID currentUserId) {
        Poll poll = pollRepository.findById(pollId)
                .orElseThrow(() -> new ApiException(ErrorCode.VALIDATION_ERROR, "Poll not found"));

        List<PollOption> options = pollOptionRepository.findByPollIdOrderByOptionOrderAsc(pollId);
        List<PollVote> allVotes = pollVoteRepository.findByPollId(pollId);

        List<iuh.cnm.vnalo.messagingservice.model.dto.response.message.PollResponse.PollOptionResponse> optionResponses = options.stream()
                .map(opt -> iuh.cnm.vnalo.messagingservice.model.dto.response.message.PollResponse.PollOptionResponse.builder()
                        .optionId(opt.getOptionId())
                        .optionText(opt.getText())
                        .voteCount(opt.getVoteCount())
                        .isVotedByCurrentUser(allVotes.stream().anyMatch(v -> v.getOptionId().equals(opt.getOptionId()) && v.getUserId().equals(currentUserId)))
                        .build())
                .toList();

        return iuh.cnm.vnalo.messagingservice.model.dto.response.message.PollResponse.builder()
                .pollId(poll.getPollId())
                .conversationId(poll.getConversationId())
                .question(poll.getQuestion())
                .allowMultipleVotes(poll.getAllowMultiple())
                .expiresAt(poll.getExpiresAt() != null ? java.time.LocalDateTime.ofInstant(poll.getExpiresAt(), java.time.ZoneOffset.UTC) : null)
                .status(poll.getStatus())
                .createdBy(poll.getCreatorId())
                .createdAt(poll.getCreatedAt() != null ? java.time.LocalDateTime.ofInstant(poll.getCreatedAt(), java.time.ZoneOffset.UTC) : null)
                .options(optionResponses)
                .build();
    }
}
