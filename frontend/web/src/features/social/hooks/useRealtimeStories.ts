import { useEffect } from 'react';
import { getOrCreateSocket } from '../../chat/chat.socket';
import { useAuth } from '../../auth/useAuth';
import type { Story, StoryViewer } from '../api/social.api';
import { storyStore } from '../store/story.store';

export interface RealtimeStoryEvents {
  onStoryCreated?: (story: Story) => void;
  onStoryDeleted?: (payload: { storyId: string }) => void;
  onStoryViewed?: (payload: { storyId: string; viewerId?: string; viewedAt?: string }) => void;
  onStoryExpired?: (payload: { storyId: string }) => void;
}

export function useRealtimeStories(events?: RealtimeStoryEvents) {
  const { accessToken } = useAuth();

  useEffect(() => {
    if (!accessToken) return;

    const socket = getOrCreateSocket(accessToken);
    if (!socket) return;

    const callbacks = events ?? {};

    const handleCreated = (story: Story) => {
      storyStore.upsertStory(story);
      callbacks.onStoryCreated?.(story);
    };

    const handleDeleted = (payload: { storyId: string }) => {
      storyStore.removeStory(payload.storyId);
      callbacks.onStoryDeleted?.(payload);
    };

    const handleViewed = (payload: { storyId: string; viewerId?: string; viewedAt?: string }) => {
      const current = storyStore.getState().viewersByStoryId[payload.storyId] ?? [];
      if (payload.viewerId) {
        const nextViewer: StoryViewer = {
          viewId: `${payload.storyId}:${payload.viewerId}:${payload.viewedAt ?? Date.now()}`,
          storyId: payload.storyId,
          viewerId: payload.viewerId,
          viewedAt: payload.viewedAt ?? new Date().toISOString(),
        };
        storyStore.setViewers(payload.storyId, [nextViewer, ...current.filter(item => item.viewerId !== payload.viewerId)]);
      }
      callbacks.onStoryViewed?.(payload);
    };

    const handleExpired = (payload: { storyId: string }) => {
      storyStore.removeStory(payload.storyId);
      callbacks.onStoryExpired?.(payload);
    };

    socket.on('story.created', handleCreated);
    socket.on('story.deleted', handleDeleted);
    socket.on('story.viewed', handleViewed);
    socket.on('story.expired', handleExpired);

    return () => {
      socket.off('story.created', handleCreated);
      socket.off('story.deleted', handleDeleted);
      socket.off('story.viewed', handleViewed);
      socket.off('story.expired', handleExpired);
    };
  }, [accessToken, events?.onStoryCreated, events?.onStoryDeleted, events?.onStoryViewed, events?.onStoryExpired]);
}
