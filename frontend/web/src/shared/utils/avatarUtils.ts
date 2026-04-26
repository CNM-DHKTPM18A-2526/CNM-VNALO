import type { ConversationSummary } from '../../features/chat/chat.types'

/**
 * Resolves avatar URLs for a group collage.
 * @param conversation The conversation summary
 * @param userMap A map of user profiles from the store
 * @returns An array of up to 3 avatar URLs and the count of remaining members
 */
export function getGroupCollageData(
  conversation: ConversationSummary,
  userMap: Record<string, { avatarUrl: string | null; displayName?: string }>
): { avatars: (string | null)[]; extraCount: number } {
  if (!conversation.participantUserIds || conversation.participantUserIds.length === 0) {
    return { avatars: [], extraCount: 0 }
  }

  // Use all members to build the collage (including creator)
  const allUserIds = (conversation.members && conversation.members.length > 0)
    ? conversation.members.map(m => m.userId)
    : (conversation.participantUserIds || []);
  
  const avatars = allUserIds
    .map(id => userMap[id]?.avatarUrl)
    .filter((url): url is string => !!url) // We only want valid image URLs for the collage
    .slice(0, 3);

  const extraCount = Math.max(0, allUserIds.length - 3);

  return { 
    avatars, 
    extraCount 
  };
}
