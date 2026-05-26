import { useSyncExternalStore } from 'react';
import type { Story, StoryViewer } from '../api/social.api';

export type StoryDraftMode = 'media' | 'text';

export interface StoryDraft {
  mode: StoryDraftMode;
  mediaUrl: string | null;
  mediaType: 'image' | 'video' | null;
  caption: string;
  background: string;
  textColor: string;
  fontSize: number;
  fontWeight: number;
  textAlign: 'left' | 'center' | 'right';
  overlayX: number;
  overlayY: number;
  overlayScale: number;
  overlayRotation: number;
}

interface StoryState {
  stories: Story[];
  activeStoryId: string | null;
  viewersByStoryId: Record<string, StoryViewer[]>;
  uploading: boolean;
  loading: boolean;
  draft: StoryDraft | null;
}

const DEFAULT_DRAFT: StoryDraft = {
  mode: 'media',
  mediaUrl: null,
  mediaType: null,
  caption: '',
  background: 'linear-gradient(180deg, #0f172a 0%, #111827 50%, #030712 100%)',
  textColor: '#ffffff',
  fontSize: 28,
  fontWeight: 700,
  textAlign: 'center',
  overlayX: 50,
  overlayY: 72,
  overlayScale: 1,
  overlayRotation: 0,
};

const state: StoryState = {
  stories: [],
  activeStoryId: null,
  viewersByStoryId: {},
  uploading: false,
  loading: false,
  draft: DEFAULT_DRAFT,
};

const listeners = new Set<() => void>();

function emit() {
  listeners.forEach(listener => listener());
}

function setState(update: Partial<StoryState> | ((current: StoryState) => Partial<StoryState>)) {
  const nextPatch = typeof update === 'function' ? update(state) : update;
  Object.assign(state, nextPatch);
  emit();
}

function sortActiveStories(stories: Story[]) {
  return [...stories].sort((left, right) => (right.createdAt || '').localeCompare(left.createdAt || ''));
}

export const storyStore = {
  getState: () => state,
  subscribe: (listener: () => void) => {
    listeners.add(listener);
    return () => listeners.delete(listener);
  },
  hydrateStories: (stories: Story[]) => setState({ stories: sortActiveStories(stories) }),
  upsertStory: (story: Story) => setState(current => ({ stories: sortActiveStories([story, ...current.stories.filter(item => item.storyId !== story.storyId)]) })),
  removeStory: (storyId: string) => setState(current => ({ stories: current.stories.filter(item => item.storyId !== storyId) })),
  setActiveStory: (storyId: string | null) => setState({ activeStoryId: storyId }),
  setViewers: (storyId: string, viewers: StoryViewer[]) => setState(current => ({ viewersByStoryId: { ...current.viewersByStoryId, [storyId]: viewers } })),
  setUploading: (uploading: boolean) => setState({ uploading }),
  setLoading: (loading: boolean) => setState({ loading }),
  setDraft: (draft: StoryDraft | null) => setState({ draft }),
  resetDraft: () => setState({ draft: DEFAULT_DRAFT }),
  defaultDraft: DEFAULT_DRAFT,
};

export function useStoryStore<T>(selector: (state: StoryState) => T): T {
  return useSyncExternalStore(
    storyStore.subscribe,
    () => selector(state),
    () => selector(state),
  );
}
