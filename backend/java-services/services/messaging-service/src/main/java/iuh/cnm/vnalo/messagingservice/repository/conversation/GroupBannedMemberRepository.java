package iuh.cnm.vnalo.messagingservice.repository.conversation;

import iuh.cnm.vnalo.messagingservice.model.entity.conversation.GroupBannedMember;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface GroupBannedMemberRepository extends JpaRepository<GroupBannedMember, GroupBannedMember.BannedMemberId> {
    boolean existsByConversationIdAndUserId(UUID conversationId, UUID userId);
    List<GroupBannedMember> findByConversationId(UUID conversationId);
    void deleteByConversationIdAndUserId(UUID conversationId, UUID userId);
}
