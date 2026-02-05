package iuh.cnm.vnalo.core_service.service;

import iuh.cnm.vnalo.core_service.exception.ApiException;
import iuh.cnm.vnalo.core_service.exception.ErrorCode;
import iuh.cnm.vnalo.core_service.model.dto.response.BlockedUserResponse;
import iuh.cnm.vnalo.core_service.model.entity.social.BlockList;
import iuh.cnm.vnalo.core_service.model.entity.user.UserProfile;
import iuh.cnm.vnalo.core_service.repository.social.BlockListRepository;
import iuh.cnm.vnalo.core_service.repository.social.FriendshipRepository;
import iuh.cnm.vnalo.core_service.repository.user.UserProfileRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class BlockService {

    private final BlockListRepository blockListRepository;
    private final FriendshipRepository friendshipRepository;
    private final UserProfileRepository userProfileRepository;

    @Transactional
    public void blockUser(UUID blockerId, UUID blockedId, Boolean blockMessages, Boolean blockCalls, Boolean blockAndHideLogs) {
        if (blockerId.equals(blockedId)) {
            throw new ApiException(ErrorCode.SOCIAL_CANNOT_ADD_SELF);
        }

        if (!userProfileRepository.existsById(blockedId)) {
            throw new ApiException(ErrorCode.USER_NOT_FOUND);
        }

        if (blockListRepository.existsByBlockerIdAndBlockedId(blockerId, blockedId)) {
            throw new ApiException(ErrorCode.SOCIAL_ALREADY_BLOCKED);
        }

        BlockList block = BlockList.builder()
                .blockerId(blockerId)
                .blockedId(blockedId)
                .blockMessages(blockMessages != null ? blockMessages : true)
                .blockCalls(blockCalls != null ? blockCalls : true)
                .blockAndHideLogs(blockAndHideLogs != null ? blockAndHideLogs : false)
                .build();
        blockListRepository.save(block);

        if (friendshipRepository.areFriends(blockerId, blockedId)) {
            friendshipRepository.deleteFriendship(blockerId, blockedId);
        }
    }

    @Transactional
    public void unblockUser(UUID blockerId, UUID blockedId) {
        BlockList block = blockListRepository.findByBlockerIdAndBlockedId(blockerId, blockedId)
                .orElseThrow(() -> new ApiException(ErrorCode.USER_NOT_FOUND));
        blockListRepository.delete(block);
    }

    @Transactional(readOnly = true)
    public Page<BlockedUserResponse> getBlockedUsers(UUID blockerId, Pageable pageable) {
        return blockListRepository.findByBlockerIdOrderByCreatedAtDesc(blockerId, pageable)
                .map(block -> {
                    UserProfile profile = userProfileRepository.findById(block.getBlockedId()).orElse(null);
                    return new BlockedUserResponse(
                            block.getBlockedId(),
                            profile != null ? profile.getDisplayName() : "Unknown",
                            profile != null ? profile.getAvatarUrl() : null,
                            block.getBlockMessages(),
                            block.getBlockCalls(),
                            block.getBlockAndHideLogs(),
                            block.getCreatedAt()
                    );
                });
    }

    @Transactional(readOnly = true)
    public boolean isBlocked(UUID blockerId, UUID blockedId) {
        return blockListRepository.existsByBlockerIdAndBlockedId(blockerId, blockedId);
    }

    @Transactional(readOnly = true)
    public boolean hasBlockBetween(UUID userA, UUID userB) {
        return blockListRepository.existsBlockBetween(userA, userB);
    }
}
