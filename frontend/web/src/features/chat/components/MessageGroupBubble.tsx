import { MessageBubble } from './MessageBubble'
import type { ChatMessage, MessageReactionMap, ReactionKey } from '../chat.types'
import type { MessageContextMenuAction } from './MessageContextMenu'

type MessageGroupBubbleProps = {
  messages: ChatMessage[]
  senderName?: string
  senderAvatarUrl?: string | null
  showAvatar?: boolean
  showSenderName?: boolean
  reactionStatesByMessage: Record<string, { reactions: MessageReactionMap }>
  onAddReaction: (messageId: string, reactionKey: ReactionKey) => void
  onRemoveReaction: (messageId: string, reactionKey: ReactionKey) => void
  onMessageContextMenuAction: (messageId: string, action: MessageContextMenuAction, message: ChatMessage, groupMessages?: ChatMessage[]) => void
  pinnedMessages: ChatMessage[]
  starredMessageIds: Record<string, boolean>
  recalledMessageIds: Record<string, boolean>
  isMultiSelectMode: boolean
  selectedMessageIds: string[]
  onToggleMessageSelection: (messageId: string) => void
  peerLastReadSeq?: number
  highlightedMessageId?: string | null
  currentUserId?: string
  handleReplyAction: (message: ChatMessage) => void
  handleJumpToMessage: (messageId: string) => void
  isIncoming: boolean
  isFirstInCluster: boolean
  isGroupConversation: boolean
  onOpenUserProfile?: (userId: string) => void
  onInitiateCall?: (type: 'audio' | 'video') => void
  isRecalled?: boolean
  userRole?: string
  allowMemberPin?: boolean
  onVotePoll?: (messageId: string, optionId: string) => void
}

export function MessageGroupBubble({
  messages,
  senderName,
  senderAvatarUrl,
  showAvatar,
  showSenderName,
  reactionStatesByMessage,
  onAddReaction,
  onRemoveReaction,
  onMessageContextMenuAction,
  pinnedMessages,
  starredMessageIds,
  recalledMessageIds,
  isMultiSelectMode,
  selectedMessageIds,
  onToggleMessageSelection,
  peerLastReadSeq,
  highlightedMessageId,
  currentUserId,
  handleReplyAction,
  handleJumpToMessage,
  onOpenUserProfile,
  onInitiateCall,
  isRecalled,
  userRole,
  allowMemberPin,
  onVotePoll,
}: MessageGroupBubbleProps) {
  if (messages.length === 0) return null;

  const lastMsg = messages[messages.length - 1];

  // We wrap the entire group in a container that looks like a single message visually
  // but internally it maps over individual MessageBubbles with special 'isGroupedContent' flag
  // or we just render them differently.

  // Zalo-style: Single bubble with many images/files.
  // We'll pass All messages as a virtual "attachments" array to ONE MessageBubble
  // BUT we need to handle reactions/ids per message.

  // To follow the goal: "Visually group into ONE bubble"
  // We'll create a synthetic message that contains ALL attachments properly mapped to their original IDs.

  const syntheticAttachments = messages.flatMap(m => {
    if (m.attachments && m.attachments.length > 0) {
      return m.attachments.map(att => ({
        ...att,
        originalMessageId: m.id
      }));
    }
    return [{
      url: m.mediaUrl || "",
      name: m.text || "",
      mimeType: m.mediaMimeType,
      sizeBytes: m.mediaSizeBytes,
      thumbnailUrl: m.mediaThumbnailUrl,
      originalMessageId: m.id
    }];
  });

  const syntheticMessage: ChatMessage = {
    ...lastMsg, // Use last message for metadata (timestamp, id for overall key)
    attachments: syntheticAttachments as any
  };

  return (
    <MessageBubble
      key={lastMsg.id}
      message={syntheticMessage}
      reactions={reactionStatesByMessage[lastMsg.id]?.reactions ?? {}} // Overall reactions show status of LAST message
      onAddReaction={(reactionKey) => onAddReaction?.(lastMsg.id, reactionKey)}
      onRemoveReaction={(reactionKey) => onRemoveReaction?.(lastMsg.id, reactionKey)}
      onContextMenuAction={(action, currentMsg) => onMessageContextMenuAction?.(lastMsg.id, action, currentMsg, messages)}
      senderName={senderName}
      senderAvatarUrl={senderAvatarUrl}
      showAvatar={showAvatar}
      showSenderName={showSenderName}
      isPinned={Boolean(pinnedMessages.find(pm => pm.id === lastMsg.id))}
      isStarred={Boolean(starredMessageIds[lastMsg.id])}
      isRecalled={isRecalled || Boolean(recalledMessageIds[lastMsg.id])}
      isMultiSelectMode={isMultiSelectMode}
      isSelected={selectedMessageIds.includes(lastMsg.id)}
      onToggleSelection={() => onToggleMessageSelection?.(lastMsg.id)}
      isReadByPeer={peerLastReadSeq !== undefined && lastMsg.serverSeq !== undefined && peerLastReadSeq >= lastMsg.serverSeq}
      isHighlighted={highlightedMessageId === lastMsg.id}
      currentUserId={currentUserId}
      onReply={() => handleReplyAction(lastMsg)}
      onJumpToOriginal={handleJumpToMessage}
      onOpenUserProfile={onOpenUserProfile}
      onInitiateCall={onInitiateCall}
      isVirtualGroup={true}
      groupedMessages={messages}
      userRole={userRole}
      allowMemberPin={allowMemberPin}
      onVotePoll={onVotePoll}
    />
  );
}
