import { useEffect } from 'react';
import { getOrCreateSocket } from '../../chat/chat.socket';
import { useAuth } from '../../auth/useAuth';
import type { Post, Story, Comment } from '../api/social.api';

interface RealtimeSocialEvents {
  onPostCreated?: (post: Post) => void;
  onPostUpdated?: (post: Post) => void;
  onPostDeleted?: (payload: { postId: string }) => void;
  onStoryCreated?: (story: Story) => void;
  onStoryExpired?: (payload: { storyId: string }) => void;
  onReactionUpdated?: (payload: { postId: string, likeCount: number }) => void;
  onCommentCreated?: (payload: { postId: string, comment: Comment, commentCount: number }) => void;
}

export function useRealtimeSocial(events: RealtimeSocialEvents) {
  const { accessToken } = useAuth();

  useEffect(() => {
    if (!accessToken) return;

    const socket = getOrCreateSocket(accessToken);
    if (!socket) return;

    const handlePostCreated = (data: any) => events.onPostCreated?.(data);
    const handlePostUpdated = (data: any) => events.onPostUpdated?.(data);
    const handlePostDeleted = (data: any) => events.onPostDeleted?.(data);
    const handleStoryCreated = (data: any) => events.onStoryCreated?.(data);
    const handleStoryExpired = (data: any) => events.onStoryExpired?.(data);
    const handleReactionUpdated = (data: any) => events.onReactionUpdated?.(data);
    const handleCommentCreated = (data: any) => events.onCommentCreated?.(data);

    socket.on('post.created', handlePostCreated);
    socket.on('post.updated', handlePostUpdated);
    socket.on('post.deleted', handlePostDeleted);
    socket.on('story.created', handleStoryCreated);
    socket.on('story.expired', handleStoryExpired);
    socket.on('reaction.updated', handleReactionUpdated);
    socket.on('comment.created', handleCommentCreated);

    return () => {
      socket.off('post.created', handlePostCreated);
      socket.off('post.updated', handlePostUpdated);
      socket.off('post.deleted', handlePostDeleted);
      socket.off('story.created', handleStoryCreated);
      socket.off('story.expired', handleStoryExpired);
      socket.off('reaction.updated', handleReactionUpdated);
      socket.off('comment.created', handleCommentCreated);
    };
  }, [accessToken, events]);
}
