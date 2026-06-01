import { useState, useEffect, useCallback, useRef } from 'react';
import { socialApi, type Post, type Story } from '../api/social.api';
import { useRealtimeSocial } from './useRealtimeSocial';

export function useFeed(accessToken: string | null) {
  const [posts, setPosts] = useState<Post[]>([]);
  const [stories, setStories] = useState<Story[]>([]);
  const [page, setPage] = useState(0);
  const [hasMore, setHasMore] = useState(true);
  const [isLoading, setIsLoading] = useState(true);
  const isFetchingRef = useRef(false);

  const fetchInitialData = useCallback(async () => {
    if (isFetchingRef.current) return;
    isFetchingRef.current = true;
    setIsLoading(true);
    try {
      if (!accessToken) {
        setPosts([]);
        setStories([]);
        setHasMore(false);
        return;
      }

      const [timelineRes, storiesRes] = await Promise.all([
        socialApi.getTimeline(accessToken, 0, 10),
        socialApi.getStories(accessToken).catch(() => [])
      ]);
      setPosts(timelineRes.items || []);
      setStories(storiesRes || []);
      setHasMore(!timelineRes.last);
      setPage(1);
    } catch (error) {
      console.warn('Error fetching social feed:', error);
      setPosts([]);
      setStories([]);
      setHasMore(false);
    } finally {
      setIsLoading(false);
      isFetchingRef.current = false;
    }
  }, [accessToken]);

  const loadMorePosts = useCallback(async () => {
    if (!hasMore || isLoading || isFetchingRef.current) return;
    isFetchingRef.current = true;
    setIsLoading(true);
    try {
      if (!accessToken) return;

      const timelineRes = await socialApi.getTimeline(accessToken, page, 10);
      setPosts(prev => {
        const newPosts = timelineRes.items.filter(newItem => !prev.some(p => p.postId === newItem.postId));
        return [...prev, ...newPosts];
      });
      setHasMore(!timelineRes.last);
      setPage(prev => prev + 1);
    } catch (error) {
      console.error('Error loading more posts:', error);
      setHasMore(false); // Stop attempting to fetch and prevent infinite loop on network error
    } finally {
      setIsLoading(false);
      isFetchingRef.current = false;
    }
  }, [accessToken, page, hasMore, isLoading]);

  useEffect(() => {
    fetchInitialData();
  }, [fetchInitialData]);

  // Short polling fallback: refresh timeline metadata (like/comment counts) periodically
  useEffect(() => {
    if (!accessToken) return;
    let mounted = true;
    const POLL_INTERVAL_MS = 8000; // 8s

    const poll = async () => {
      try {
        if (!mounted) return;
        // fetch first page with current posts length or default 10
        const size = Math.max(10, posts.length || 10);
        const timeline = await socialApi.getTimeline(accessToken, 0, size);
        if (!mounted) return;
        // Merge counts into existing posts to avoid reordering
        setPosts(prev => prev.map(p => {
          const updated = timeline.items.find(t => t.postId === p.postId);
          if (!updated) return p;
          return { ...p, likeCount: updated.likeCount, commentCount: updated.commentCount };
        }));
      } catch (e) {
        // ignore polling errors
      }
    };

    const id = window.setInterval(poll, POLL_INTERVAL_MS);
    return () => {
      mounted = false;
      window.clearInterval(id);
    };
  }, [accessToken, posts.length]);

  // Realtime Integration
  useRealtimeSocial({
    onPostCreated: (post) => {
      setPosts(prev => [post, ...prev.filter(p => p.postId !== post.postId)]);
    },
    onPostUpdated: (post) => {
      setPosts(prev => prev.map(p => p.postId === post.postId ? { ...p, ...post } : p));
    },
    onPostDeleted: ({ postId }) => {
      setPosts(prev => prev.filter(p => p.postId !== postId));
    },
    onReactionUpdated: ({ postId, likeCount }) => {
      setPosts(prev => prev.map(p => p.postId === postId ? { ...p, likeCount } : p));
    },
    onCommentCreated: ({ postId, commentCount }) => {
      setPosts(prev => prev.map(p => p.postId === postId ? { ...p, commentCount } : p));
    },
    onStoryCreated: (story) => {
      setStories(prev => [story, ...prev.filter(s => s.storyId !== story.storyId)]);
    },
    onStoryExpired: ({ storyId }) => {
      setStories(prev => prev.filter(s => s.storyId !== storyId));
    }
  });

  return {
    posts,
    stories,
    isLoading,
    hasMore,
    loadMorePosts,
    setPosts,
    refreshFeed: fetchInitialData,
  };
}
