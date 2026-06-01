import { contentApi, mediaApi } from '../../../api.client';

function authHeaders(token: string) {
  return {
    Authorization: `Bearer ${token}`,
  };
}

async function extractUploadedMediaUrl(response: unknown): Promise<string> {
  const payload =
    response && typeof response === 'object' && !Array.isArray(response) && 'data' in response
      ? (response as { data?: unknown }).data
      : response;

  if (payload && typeof payload === 'object' && !Array.isArray(payload)) {
    const url = (payload as { url?: unknown }).url;
    if (typeof url === 'string' && url.trim()) {
      return url;
    }
  }

  throw new Error('Upload response did not include a media URL.');
}

export interface Post {
  postId: string;
  authorId: string;
  contentText: string;
  mediaUrls: string[];
  visibility: 'PUBLIC' | 'FRIENDS' | 'PRIVATE' | string;
  likeCount: number;
  commentCount: number;
  shareCount: number;
  status: string;
  createdAt: string;
  updatedAt: string;
}

export interface Story {
  storyId: string;
  authorId: string;
  mediaUrl: string;
  caption: string;
  visibility: 'PUBLIC' | 'FRIENDS' | 'PRIVATE' | string;
  expiresAt: string;
  createdAt: string;
}

export interface StoryViewer {
  viewId: string;
  storyId: string;
  viewerId: string;
  viewedAt: string;
}

export interface StoryReaction {
  storyReactionId: string;
  storyId: string;
  userId: string;
  reactionType: string;
  createdAt: string;
}

export interface TimelineResponse {
  items: Post[];
  page: number;
  size: number;
  totalElements: number;
  totalPages: number;
  last: boolean;
}

export interface Comment {
  commentId: string;
  postId: string;
  authorId: string;
  contentText: string;
  mediaUrl?: string;
  createdAt: string;
  updatedAt: string;
}

export interface PostLike {
  userId: string;
  likedAt?: string;
}

export interface CommentPageResponse {
  items: Comment[];
  page: number;
  size: number;
  last: boolean;
}

export const socialApi = {
  // Posts
  getTimeline: async (token: string, page = 0, size = 10): Promise<TimelineResponse> => {
    const { data } = await contentApi.get('/posts/timeline', { params: { page, size }, headers: authHeaders(token) });
    return data;
  },
  createPost: async (token: string, payload: { contentText: string; mediaUrls: string[]; visibility: string }) => {
    const { data } = await contentApi.post('/posts', payload, { headers: authHeaders(token) });
    return data;
  },
  updatePost: async (token: string, postId: string, payload: { contentText: string; mediaUrls: string[]; visibility: string }) => {
    const { data } = await contentApi.put(`/posts/${postId}`, payload, { headers: authHeaders(token) });
    return data;
  },
  deletePost: async (token: string, postId: string) => {
    const { data } = await contentApi.delete(`/posts/${postId}`, { headers: authHeaders(token) });
    return data;
  },
  likePost: async (token: string, postId: string) => {
    const { data } = await contentApi.post(`/posts/${postId}/like`, undefined, { headers: authHeaders(token) });
    return data;
  },
  unlikePost: async (token: string, postId: string) => {
    const { data } = await contentApi.delete(`/posts/${postId}/like`, { headers: authHeaders(token) });
    return data;
  },
  getPostLikers: async (token: string, postId: string): Promise<PostLike[]> => {
    const { data } = await contentApi.get(`/posts/${postId}/likes`, { headers: authHeaders(token) });
    return data;
  },

  // Comments
  getComments: async (token: string, postId: string, page = 0, size = 20): Promise<CommentPageResponse> => {
    const { data } = await contentApi.get(`/posts/${postId}/comments`, { params: { page, size }, headers: authHeaders(token) });
    return data;
  },
  createComment: async (token: string, postId: string, contentText: string, parentCommentId?: string) => {
    const payload: { contentText: string; parentCommentId?: string } = { contentText };
    if (parentCommentId) payload.parentCommentId = parentCommentId;
    const { data } = await contentApi.post(`/posts/${postId}/comments`, payload, { headers: authHeaders(token) });
    return data;
  },
  updateComment: async (token: string, commentId: string, contentText: string) => {
    const { data } = await contentApi.put(`/comments/${commentId}`, { contentText }, { headers: authHeaders(token) });
    return data;
  },
  deleteComment: async (token: string, commentId: string) => {
    const { data } = await contentApi.delete(`/comments/${commentId}`, { headers: authHeaders(token) });
    return data;
  },

  // Stories
  getStories: async (token: string): Promise<Story[]> => {
    const { data } = await contentApi.get('/stories', { headers: authHeaders(token) });
    if (Array.isArray(data)) {
      return data;
    }
    if (data && typeof data === 'object') {
      const wrapped = data as { data?: unknown; items?: unknown };
      if (Array.isArray(wrapped.data)) {
        return wrapped.data as Story[];
      }
      if (Array.isArray(wrapped.items)) {
        return wrapped.items as Story[];
      }
    }
    return [];
  },
  createStory: async (token: string, payload: { mediaUrl: string; caption?: string; visibility: string }) => {
    const { data } = await contentApi.post('/stories', payload, { headers: authHeaders(token) });
    return data;
  },
  deleteStory: async (token: string, storyId: string) => {
    const { data } = await contentApi.delete(`/stories/${storyId}`, { headers: authHeaders(token) });
    return data;
  },
  viewStory: async (token: string, storyId: string) => {
    const { data } = await contentApi.post(`/stories/${storyId}/view`, undefined, { headers: authHeaders(token) });
    return data;
  },
  getStoryViews: async (token: string, storyId: string): Promise<StoryViewer[]> => {
    const { data } = await contentApi.get(`/stories/${storyId}/views`, { headers: authHeaders(token) });
    return data;
  },
  reactStory: async (token: string, storyId: string, reactionType = 'LOVE'): Promise<StoryReaction> => {
    const { data } = await contentApi.post(
      `/stories/${storyId}/reactions`,
      undefined,
      { params: { reactionType }, headers: authHeaders(token) },
    );
    return data;
  },
  unreactStory: async (token: string, storyId: string) => {
    const { data } = await contentApi.delete(`/stories/${storyId}/reactions`, { headers: authHeaders(token) });
    return data;
  },
  getStoryReactions: async (token: string, storyId: string): Promise<StoryReaction[]> => {
    const { data } = await contentApi.get(`/stories/${storyId}/reactions`, { headers: authHeaders(token) });
    return data;
  },
};

export async function uploadSocialMedia(token: string, file: File): Promise<string> {
  const formData = new FormData();
  formData.append('file', file);
  formData.append('category', file.type.startsWith('video/') ? 'CHAT_VIDEO' : 'CHAT_IMAGE');

  const response = await mediaApi.post('upload', formData, {
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'multipart/form-data',
    },
  });

  return extractUploadedMediaUrl(response.data);
}

export async function uploadStoryMedia(token: string, file: File): Promise<string> {
  const formData = new FormData();
  formData.append('file', file);
  formData.append('category', 'STORY');

  const response = await mediaApi.post('upload', formData, {
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'multipart/form-data',
    },
  });

  return extractUploadedMediaUrl(response.data);
}
