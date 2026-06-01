import { useState, useRef, useEffect, useCallback } from 'react';
import { useLocation } from 'react-router-dom';
import { useAuth } from '../../auth/useAuth';
import { useFeed } from '../hooks/useFeed';
import { StoryBar } from '../components/StoryBar';
import { FeedPostCard } from '../components/FeedPostCard';
import { CreatePostModal } from '../components/CreatePostModal';
import { UserAvatar } from '../../../shared/components/UserAvatar';
import { Icon } from '../../../shared/components/Icon';
import type { Post } from '../api/social.api';
import { useUserStore } from '../../chat/context/UserStoreContext';
import '../styles/social.css';

function FeedComposer({ onOpenModal, currentUserProfile }: { onOpenModal: () => void; currentUserProfile: { displayName: string; avatarUrl: string | null } | null }) {
  return (
    <div className="create-post-composer">
      <div className="composer-top">
        <UserAvatar
          imageUrl={currentUserProfile?.avatarUrl ?? null}
          name={currentUserProfile?.displayName ?? 'Tôi'}
          size="md"
        />
        <input
          className="composer-input"
          placeholder="Bạn đang nghĩ gì?"
          readOnly
          onClick={onOpenModal}
        />
      </div>
      <div className="composer-actions">
        <button className="composer-btn" onClick={onOpenModal}>
          <Icon name="image" size={20} /> Ảnh/Video
        </button>
        <button className="composer-btn" onClick={onOpenModal}>
          <Icon name="smile" size={20} /> Cảm xúc
        </button>
      </div>
    </div>
  );
}

export default function SocialPage() {
  const location = useLocation();
  const { accessToken, user } = useAuth();
  const { userMap, ensureUser } = useUserStore();
  const { posts, stories, isLoading, hasMore, loadMorePosts, setPosts, refreshFeed } = useFeed(accessToken);

  useEffect(() => {
    if (location.pathname === '/social') {
      void refreshFeed();
    }
  }, [location.pathname, refreshFeed]);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingPost, setEditingPost] = useState<Post | null>(null);
  const observerTarget = useRef<HTMLDivElement>(null);

  const handleObserver = useCallback(
    (entries: IntersectionObserverEntry[]) => {
      const [target] = entries;
      if (target.isIntersecting && hasMore && !isLoading) {
        loadMorePosts();
      }
    },
    [hasMore, isLoading, loadMorePosts]
  );

  useEffect(() => {
    const element = observerTarget.current;
    if (!element) return;
    const observer = new IntersectionObserver(handleObserver, { threshold: 0.1 });
    observer.observe(element);
    return () => { if (element) observer.unobserve(element); };
  }, [handleObserver]);

  const handleLikeUpdate = (postId: string, newCount: number, _isLiked: boolean) => {
    setPosts(prev => prev.map(p => p.postId === postId ? { ...p, likeCount: newCount } : p));
  };

  const handleDeletePost = (postId: string) => {
    setPosts(prev => prev.filter(post => post.postId !== postId));
  };

  const handleEditPost = (post: Post) => {
    setEditingPost(post);
    setIsModalOpen(true);
  };

  const handleCommentCreated = (postId: string, newCount: number) => {
    setPosts(prev => prev.map(p => p.postId === postId ? { ...p, commentCount: newCount } : p));
  };

  const handleClosePostModal = () => {
    setIsModalOpen(false);
    setEditingPost(null);
  };

  const handlePostUpdated = (updatedPost: Post) => {
    setPosts(prev => prev.map(post => (post.postId === updatedPost.postId ? updatedPost : post)));
  };

  // Optimistic prepend: thêm bài viết mới lên đầu feed ngay lập tức
  const handlePostCreated = (newPost: Post) => {
    setPosts(prev => {
      // Avoid exact duplicates by postId.
      if (prev.some(post => post.postId === newPost.postId)) {
        return prev;
      }

      const isServerPost = !newPost.postId.startsWith('local-');
      if (isServerPost) {
        // Reconcile: replace a matching optimistic local post when server response arrives.
        const localIndex = prev.findIndex(post =>
          post.postId.startsWith('local-')
          && post.contentText === newPost.contentText
          && JSON.stringify(post.mediaUrls ?? []) === JSON.stringify(newPost.mediaUrls ?? [])
        );

        if (localIndex >= 0) {
          const next = [...prev];
          next.splice(localIndex, 1);
          return [newPost, ...next];
        }
      }

      return [newPost, ...prev];
    });
  };

  useEffect(() => {
    if (!accessToken) return;

    const authorIds = new Set<string>();
    posts.forEach((post) => {
      if (post.authorId) authorIds.add(post.authorId);
    });
    stories.forEach((story) => {
      if (story.authorId) authorIds.add(story.authorId);
    });

    void Promise.all(
      [...authorIds].map((userId) => ensureUser(accessToken, userId).catch(() => null))
    );
  }, [accessToken, posts, stories, ensureUser]);

  const currentUserProfile = user
    ? {
        displayName: user.name?.trim() || user.email || 'Tôi',
        avatarUrl: user.avatarUrl ?? null,
      }
    : null;

  return (
    <div className="social-layout">
      {/* CENTER FEED */}
      <main className="social-center-feed">
        <div className="social-feed-container">
          <StoryBar
            stories={stories}
            authorProfiles={userMap as Record<string, { displayName: string; avatarUrl: string | null }>}
            currentUserId={user?.id ?? null}
          />

          <FeedComposer onOpenModal={() => setIsModalOpen(true)} currentUserProfile={currentUserProfile} />

          {posts.map(post => (
            <FeedPostCard
              key={post.postId}
              post={post}
              onLikeUpdate={handleLikeUpdate}
              onDeletePost={handleDeletePost}
              onEditPost={handleEditPost}
              onCommentCreated={handleCommentCreated}
              accessToken={accessToken}
              authorProfile={userMap[post.authorId] ?? null}
              currentUserId={user?.id ?? null}
            />
          ))}

          {isLoading && (
            <div className="feed-post-card social-skeleton" style={{ height: '200px' }} />
          )}

          <div ref={observerTarget} style={{ height: '20px' }} />
        </div>
      </main>

      <CreatePostModal
        isOpen={isModalOpen}
        onClose={handleClosePostModal}
        onPostCreated={handlePostCreated}
        onPostUpdated={handlePostUpdated}
        accessToken={accessToken}
        currentUserProfile={currentUserProfile}
        editingPost={editingPost}
      />
    </div>
  );
}

