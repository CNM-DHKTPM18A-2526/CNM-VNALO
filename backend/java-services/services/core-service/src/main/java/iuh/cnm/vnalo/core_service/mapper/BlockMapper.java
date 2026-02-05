package iuh.cnm.vnalo.core_service.mapper;

import iuh.cnm.vnalo.core_service.model.dto.response.BlockedUserResponse;
import iuh.cnm.vnalo.core_service.model.entity.social.BlockList;
import iuh.cnm.vnalo.core_service.model.entity.user.UserProfile;
import org.springframework.stereotype.Component;

/**
 * Mapper for converting between Block entities and DTOs.
 */
@Component
public class BlockMapper {

    /**
     * Map BlockList entity to BlockedUserResponse.
     *
     * @param block   the block list entry
     * @param profile the blocked user's profile (can be null)
     * @return BlockedUserResponse DTO
     */
    public BlockedUserResponse toBlockedUserResponse(BlockList block, UserProfile profile) {
        if (block == null) {
            return null;
        }
        
        return new BlockedUserResponse(
                block.getBlockedId(),
                profile != null ? profile.getDisplayName() : "Unknown",
                profile != null ? profile.getAvatarUrl() : null,
                block.getBlockMessages(),
                block.getBlockCalls(),
                block.getBlockAndHideLogs(),
                block.getCreatedAt()
        );
    }
}
