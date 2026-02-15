package iuh.cnm.vnalo.messagingservice.repository.conversation;

import iuh.cnm.vnalo.messagingservice.model.entity.conversation.ConversationMember;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ConversationMemberRepository extends JpaRepository<ConversationMember, ConversationMember.ConversationMemberId> {
    List<ConversationMember> findByConversationIdAndLeftAtIsNull(UUID conversationId);
    List<ConversationMember> findByUserIdAndLeftAtIsNull(UUID userId);
    Optional<ConversationMember> findByConversationIdAndUserId(UUID conversationId, UUID userId);
    boolean existsByConversationIdAndUserIdAndLeftAtIsNull(UUID conversationId, UUID userId);
    long countByConversationIdAndLeftAtIsNull(UUID conversationId);
}
