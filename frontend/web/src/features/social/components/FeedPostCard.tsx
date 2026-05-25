import { useEffect, useRef, useState } from 'react';
import { type Post, type Comment as ApiComment, socialApi } from '../api/social.api';
import { Icon } from '../../../shared/components/Icon';
import { UserAvatar } from '../../../shared/components/UserAvatar';
import { useUserStore } from '../../chat/context/UserStoreContext';
import { MEDIA_API_URL } from '../../../api.client';
import MediaLightbox from './MediaLightbox';
import { REACTION_OPTIONS } from '../../chat/chat.constants';

type AuthorProfile = {
  displayName: string
  avatarUrl: string | null
}

export function FeedPostCard({
  post,
  onLikeUpdate,
  onDeletePost,
  onEditPost,
  onCommentCreated,
  accessToken,
  authorProfile,
  currentUserId,
}: {
  post: Post
  onLikeUpdate: (id: string, newCount: number, isLiked: boolean) => void
  onDeletePost: (id: string) => void
  onEditPost: (post: Post) => void
  onCommentCreated: (postId: string, newCount: number) => void
  accessToken: string | null
  authorProfile?: AuthorProfile | null
  currentUserId: string | null
}) {
  const [isLiking, setIsLiking] = useState(false);
  const [isLiked, setIsLiked] = useState(false); // persisted per-user in localStorage if backend doesn't provide flag
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const [isConfirmOpen, setIsConfirmOpen] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const [activeCommentMenuId, setActiveCommentMenuId] = useState<string | null>(null);
  const menuRef = useRef<HTMLDivElement | null>(null);
  const canDelete = Boolean(currentUserId && post.authorId === currentUserId);

  useEffect(() => {
    if (!isMenuOpen && !activeCommentMenuId) return;

    const handlePointerDown = (event: PointerEvent) => {
      const target = event.target as HTMLElement | null;
      if (!target) return;

      if (!target.closest('.post-menu-wrapper') && !target.closest('.comment-menu-wrapper')) {
        setIsMenuOpen(false);
        setActiveCommentMenuId(null);
      }
    };

    window.addEventListener('pointerdown', handlePointerDown);
    return () => window.removeEventListener('pointerdown', handlePointerDown);
  }, [isMenuOpen, activeCommentMenuId]);

  // Initialize liked state: prefer server-provided flag if present, otherwise fall back to localStorage
  useEffect(() => {
    const serverFlag = (post as any).isLiked ?? (post as any).likedByCurrentUser ?? (post as any).liked;
    if (serverFlag !== undefined) {
      setIsLiked(Boolean(serverFlag));
      return;
    }

    if (!currentUserId) return;
    try {
      const stored = localStorage.getItem(`liked:${currentUserId}:${post.postId}`);
      setIsLiked(stored === '1');
    } catch (e) {
      // ignore storage errors
    }
  }, [post.postId, currentUserId, post]);

  const handleDeletePost = async () => {
    if (isDeleting) return;
    setIsDeleting(true);
    try {
      if (!accessToken) {
        throw new Error('Missing access token');
      }

      await socialApi.deletePost(accessToken, post.postId);
      onDeletePost(post.postId);
      setIsConfirmOpen(false);
      setIsMenuOpen(false);
    } catch (e) {
      console.error('Delete failed', e);
    } finally {
      setIsDeleting(false);
    }
  };

  const handleLike = async () => {
    if (isLiking) return;
    setIsLiking(true);
    try {
      if (!accessToken) {
        throw new Error('Missing access token');
      }

      if (isLiked) {
        await socialApi.unlikePost(accessToken, post.postId);
        setIsLiked(false);
        onLikeUpdate(post.postId, Math.max(0, post.likeCount - 1), false);
        // update per-user flag
        if (currentUserId) localStorage.setItem(`liked:${currentUserId}:${post.postId}`, '0');
        // remove from per-post likers cache
        try {
          const key = `likedUsers:${post.postId}`;
          const raw = localStorage.getItem(key);
          if (raw) {
            const arr: string[] = JSON.parse(raw);
            const next = arr.filter(id => id !== currentUserId);
            localStorage.setItem(key, JSON.stringify(next));
          }
        } catch (e) {}
      } else {
        await socialApi.likePost(accessToken, post.postId);
        setIsLiked(true);
        onLikeUpdate(post.postId, post.likeCount + 1, true);
        if (currentUserId) localStorage.setItem(`liked:${currentUserId}:${post.postId}`, '1');
        // add to per-post likers cache
        try {
          const key = `likedUsers:${post.postId}`;
          const raw = localStorage.getItem(key);
          const arr: string[] = raw ? JSON.parse(raw) : [];
          if (currentUserId && !arr.includes(currentUserId)) {
            arr.unshift(currentUserId);
            localStorage.setItem(key, JSON.stringify(arr.slice(0, 200)));
          }
        } catch (e) {}
      }
    } catch (e) {
      console.error('Like failed', e);
    } finally {
      setIsLiking(false);
    }
  };

  const getMediaUrl = (url: string) => {
    if (!url) return '';
    const trimmed = url.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) return trimmed;

    // Remove leading slashes
    const cleaned = trimmed.replace(/^\/+/, '');

    // If the returned url already contains 'uploads/' prefix, append directly to MEDIA_API_URL
    if (cleaned.startsWith('uploads/')) return `${MEDIA_API_URL}${cleaned}`;

    // Otherwise assume it's a bare filename or path and place under uploads/
    return `${MEDIA_API_URL}uploads/${cleaned}`;
  };

  const mediaCount = post.mediaUrls?.length || 0;
  let gridClass = 'grid-1';
  if (mediaCount === 2) gridClass = 'grid-2';
  else if (mediaCount === 3) gridClass = 'grid-3';
  else if (mediaCount >= 4) gridClass = 'grid-4';

  const displayMedia = post.mediaUrls?.slice(0, 4) || [];
  const authorName = authorProfile?.displayName?.trim() || `User ${post.authorId.substring(0, 4)}`;
  const authorAvatar = authorProfile?.avatarUrl ?? null;

  const [lightboxIndex, setLightboxIndex] = useState<number | null>(null);
  const { userMap, ensureUser } = useUserStore();
  const [isLikersOpen, setIsLikersOpen] = useState(false);
  const [likers, setLikers] = useState<{ userId: string; likedAt?: string }[] | null>(null);
  const [isCommentsOpen, setIsCommentsOpen] = useState(false);
  const [comments, setComments] = useState<ApiComment[] | null>(null);
  const [commentInput, setCommentInput] = useState('');
  const [isPostingComment, setIsPostingComment] = useState(false);
  const [isCommentEmojiPickerOpen, setIsCommentEmojiPickerOpen] = useState(false);
  const commentInputRef = useRef<HTMLTextAreaElement | null>(null);
  const [editingCommentId, setEditingCommentId] = useState<string | null>(null);
  const [editingCommentText, setEditingCommentText] = useState('');
  const [isSavingCommentEdit, setIsSavingCommentEdit] = useState(false);
  const [commentToDelete, setCommentToDelete] = useState<ApiComment | null>(null);
  const [isDeletingComment, setIsDeletingComment] = useState(false);

  const emojiOptions = [...REACTION_OPTIONS.map(item => item.emoji), '😊', '🥳', '✨', '💖', '😄', '🤩', '🙌', '🔥'];

  const insertCommentEmoji = (emoji: string) => {
    setCommentInput(prev => {
      const textarea = commentInputRef.current;
      if (!textarea) {
        return `${prev}${emoji}`;
      }

      const start = textarea.selectionStart ?? prev.length;
      const end = textarea.selectionEnd ?? prev.length;
      const nextValue = `${prev.slice(0, start)}${emoji}${prev.slice(end)}`;

      window.requestAnimationFrame(() => {
        const nextCursor = start + emoji.length;
        textarea.focus();
        textarea.setSelectionRange(nextCursor, nextCursor);
      });

      return nextValue;
    });
  };

  const startEditComment = (comment: ApiComment) => {
    setActiveCommentMenuId(null);
    setEditingCommentId(comment.commentId);
    setEditingCommentText(comment.contentText ?? '');
    setIsCommentEmojiPickerOpen(false);
  };

  const cancelEditComment = () => {
    setEditingCommentId(null);
    setEditingCommentText('');
  };

  const saveCommentEdit = async () => {
    if (!accessToken || !editingCommentId) return;
    const nextText = editingCommentText.trim();
    if (!nextText) return;

    setIsSavingCommentEdit(true);
    try {
      const updated = await socialApi.updateComment(accessToken, editingCommentId, nextText);
      setComments(prev => prev?.map(comment => comment.commentId === editingCommentId ? { ...comment, ...updated } : comment) ?? prev);
      cancelEditComment();
    } catch (e) {
      console.error('Update comment failed', e);
    } finally {
      setIsSavingCommentEdit(false);
    }
  };

  const confirmDeleteComment = (comment: ApiComment) => {
    setActiveCommentMenuId(null);
    setCommentToDelete(comment);
  };

  const handleDeleteComment = async () => {
    if (!accessToken || !commentToDelete) return;

    setIsDeletingComment(true);
    try {
      await socialApi.deleteComment(accessToken, commentToDelete.commentId);
      setComments(prev => prev?.filter(comment => comment.commentId !== commentToDelete.commentId) ?? prev);
      onCommentCreated(post.postId, Math.max(0, post.commentCount - 1));
      setCommentToDelete(null);
    } catch (e) {
      console.error('Delete comment failed', e);
    } finally {
      setIsDeletingComment(false);
    }
  };

  const canManageComment = (comment: ApiComment) => {
    return Boolean(currentUserId && (comment.authorId === currentUserId || post.authorId === currentUserId));
  };

  const canEditComment = (comment: ApiComment) => Boolean(currentUserId && comment.authorId === currentUserId);

  return (
    <div className="feed-post-card">
      <div className="post-header">
        <div className="post-author-info">
          <UserAvatar imageUrl={authorAvatar} name={authorName} size="md" />
          <div className="post-author-details">
            <span className="post-author-name">{authorName}</span>
            <div className="post-meta">
              <span>{new Date(post.createdAt).toLocaleString()}</span>
              <span>•</span>
              <Icon name={post.visibility === 'PUBLIC' ? 'group' : 'user'} size={12} />
            </div>
          </div>
        </div>
        {canDelete && (
          <div className="post-menu-wrapper" ref={menuRef}>
            <button
              type="button"
              className="composer-btn post-menu-trigger"
              style={{ padding: '4px' }}
              aria-haspopup="menu"
              aria-expanded={isMenuOpen}
              onClick={() => setIsMenuOpen(prev => !prev)}
            >
              <Icon name="more" size={20} />
            </button>

            {isMenuOpen && (
              <div className="post-menu" role="menu">
                <button
                  type="button"
                  className="post-menu-item post-menu-item-danger"
                  role="menuitem"
                  onClick={() => {
                    setIsMenuOpen(false);
                    setIsConfirmOpen(true);
                  }}
                >
                  Xóa bài viết
                </button>
                <button
                  type="button"
                  className="post-menu-item"
                  role="menuitem"
                  onClick={() => {
                    setIsMenuOpen(false);
                    onEditPost(post);
                  }}
                >
                  Chỉnh sửa bài viết
                </button>
              </div>
            )}
          </div>
        )}
      </div>

      <div className="post-content">
        {post.contentText}
      </div>

      {mediaCount > 0 && (
        <div className={`feed-media-grid ${gridClass}`}>
          {displayMedia.map((url, idx) => {
            const finalUrl = getMediaUrl(url);
            const isVideo = /\.(mp4|webm|ogg)(\?.*)?$/.test(finalUrl);
            return (
              <div key={idx} className="media-item-wrapper" onClick={() => setLightboxIndex(idx)}>
                {isVideo ? (
                  <video src={finalUrl} className="media-item" controls preload="metadata" />
                ) : (
                  <img src={finalUrl} alt="" className="media-item" loading="lazy" />
                )}
                {idx === 3 && mediaCount > 4 && (
                  <div className="media-overlay-count">
                    +{mediaCount - 4}
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}

      {lightboxIndex !== null && (
        <MediaLightbox items={post.mediaUrls} startIndex={lightboxIndex} onClose={() => setLightboxIndex(null)} />
      )}

      <div className="post-stats">
        <button type="button" className="post-stats-like-count" onClick={async () => {
          // Open likers modal and fetch list; fallback to local cache (current user's like) if server returns nothing
          setIsLikersOpen(true);
          setLikers(null);
          try {
            if (!accessToken) {
              // No auth: fallback to localStorage
              const fallback: { userId: string; likedAt?: string }[] = [];
              try {
                if (currentUserId && localStorage.getItem(`liked:${currentUserId}:${post.postId}`) === '1') {
                  fallback.push({ userId: currentUserId, likedAt: new Date().toISOString() });
                }
              } catch (e) {}
              setLikers(fallback);
              return;
            }

            const data = await socialApi.getPostLikers(accessToken, post.postId).catch(() => null);
            // read local per-post cache
            let localArr: { userId: string; likedAt?: string }[] = [];
            try {
              const key = `likedUsers:${post.postId}`;
              const raw = localStorage.getItem(key);
              if (raw) {
                const ids: string[] = JSON.parse(raw);
                localArr = ids.map(id => ({ userId: id }));
              }
            } catch (e) {
              localArr = [];
            }

            if (data && Array.isArray(data) && data.length > 0) {
              // merge server data with local cache (server first), dedupe by userId
              const map = new Map<string, { userId: string; likedAt?: string }>();
              data.forEach((d: any) => map.set(d.userId, { userId: d.userId, likedAt: d.likedAt }));
              localArr.forEach(l => { if (!map.has(l.userId)) map.set(l.userId, l); });
              const merged = Array.from(map.values());
              setLikers(merged);
              void Promise.all(merged.slice(0, 10).map(d => ensureUser(accessToken, d.userId).catch(() => null)));
              return;
            }

            // Server returned empty list — use fallback local per-post cache or current user
            const fallbackList: { userId: string; likedAt?: string }[] = [];
            if (localArr.length > 0) {
              fallbackList.push(...localArr);
              // prefetch profiles
              void Promise.all(localArr.slice(0, 10).map(d => ensureUser(accessToken, d.userId).catch(() => null)));
            } else {
              try {
                if (currentUserId && localStorage.getItem(`liked:${currentUserId}:${post.postId}`) === '1') {
                  fallbackList.push({ userId: currentUserId, likedAt: new Date().toISOString() });
                  void ensureUser(accessToken, currentUserId).catch(() => null);
                }
              } catch (e) {}
            }

            setLikers(fallbackList);
          } catch (e) {
            console.warn('Failed to fetch likers', e);
            const fallbackErr: { userId: string; likedAt?: string }[] = [];
            try {
              if (currentUserId && localStorage.getItem(`liked:${currentUserId}:${post.postId}`) === '1') {
                fallbackErr.push({ userId: currentUserId, likedAt: new Date().toISOString() });
              }
            } catch (err) {}
            setLikers(fallbackErr);
          }
        }}>
          {post.likeCount} Thích
        </button>
        <span>{post.commentCount} Bình luận</span>
      </div>

      <div className="post-actions">
        <button className={`post-action-btn ${isLiked ? 'liked' : ''}`} onClick={handleLike} disabled={isLiking}>
          <Icon name={isLiked ? 'heartFill' : 'heart'} size={20} />
          {isLiked ? 'Đã thích' : 'Thích'}
        </button>
        <button className="post-action-btn" onClick={async () => {
          setIsCommentsOpen(true);
          setComments(null);
          try {
            if (!accessToken) {
              setComments([]);
              return;
            }
            const res = await socialApi.getComments(accessToken, post.postId, 0, 50).catch(() => ({ items: [] }));
            setComments(res.items || []);
          } catch (e) {
            console.warn('Failed to fetch comments', e);
            setComments([]);
          }
        }}>
          <Icon name="chat" size={20} />
          Bình luận
        </button>
        {/* Share button intentionally removed per UX request */}
      </div>

      {isConfirmOpen && (
        <div className="social-modal-overlay social-confirm-overlay" onClick={() => setIsConfirmOpen(false)}>
          <div className="social-confirm-modal" onClick={e => e.stopPropagation()}>
            <div className="social-confirm-header">
              <h3>Xóa bài viết</h3>
              <button type="button" className="composer-btn" onClick={() => setIsConfirmOpen(false)} style={{ padding: '4px' }}>
                <Icon name="close" size={20} />
              </button>
            </div>
            <div className="social-confirm-body">
              <p>Bạn có chắc muốn xóa bài viết này không? Hành động này không thể hoàn tác.</p>
            </div>
            <div className="social-confirm-footer">
              <button type="button" className="composer-btn" onClick={() => setIsConfirmOpen(false)}>
                Hủy
              </button>
              <button type="button" className="composer-btn primary" onClick={handleDeletePost} disabled={isDeleting}>
                {isDeleting ? 'Đang xóa...' : 'Xóa bài viết'}
              </button>
            </div>
          </div>
        </div>
      )}

      {isLikersOpen && (
        <div className="social-modal-overlay" onClick={() => setIsLikersOpen(false)}>
          <div className="social-modal-content" onClick={e => e.stopPropagation()}>
            <div className="social-modal-header">
              <h3>Ai đã thích</h3>
              <button type="button" className="composer-btn" onClick={() => setIsLikersOpen(false)} style={{ padding: '4px' }}>
                <Icon name="close" size={20} />
              </button>
            </div>
            <div className="social-modal-body">
              {likers === null && <div>Đang tải…</div>}
              {likers && likers.length === 0 && <div>Chưa có ai thích</div>}
              {likers && likers.length > 0 && (
                <div className="likers-list">
                  {likers.map((l) => {
                    const profile = userMap[l.userId];
                    return (
                      <div key={l.userId} className="liker-row">
                        <UserAvatar imageUrl={profile?.avatarUrl ?? null} name={profile?.displayName ?? l.userId} size="sm" />
                        <div className="liker-info">
                          <div className="liker-name">{profile?.displayName ?? l.userId}</div>
                          {l.likedAt && <div className="liker-time">{new Date(l.likedAt).toLocaleString()}</div>}
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
            <div className="social-modal-footer">
              <button type="button" className="composer-btn" onClick={() => setIsLikersOpen(false)}>Đóng</button>
            </div>
          </div>
        </div>
      )}

      {isCommentsOpen && (
        <div className="social-modal-overlay" onClick={() => setIsCommentsOpen(false)}>
          <div className="social-modal-content" onClick={e => e.stopPropagation()}>
            <div className="social-modal-header">
              <h3>Bài viết</h3>
              <button type="button" className="composer-btn" onClick={() => setIsCommentsOpen(false)} style={{ padding: '4px' }}>
                <Icon name="close" size={20} />
              </button>
            </div>
            <div className="social-modal-body">
              <div className="comment-post-preview">
                <div className="post-author-info">
                  <UserAvatar imageUrl={authorAvatar} name={authorName} size="sm" />
                  <div className="post-author-details">
                    <span className="post-author-name">{authorName}</span>
                    <div className="post-meta"><span>{new Date(post.createdAt).toLocaleString()}</span></div>
                  </div>
                </div>
                    <div className="post-content">{post.contentText}</div>

                    {mediaCount > 0 && (
                      <div className="modal-media-preview">
                        {displayMedia.length === 1 ? (
                          (() => {
                            const finalUrl = getMediaUrl(displayMedia[0]);
                            const isVideo = /\.(mp4|webm|ogg)(\?.*)?$/.test(finalUrl);
                            return isVideo ? (
                              <video src={finalUrl} className="modal-media-single" controls preload="metadata" />
                            ) : (
                              <img src={finalUrl} alt="" className="modal-media-single" />
                            );
                          })()
                        ) : (
                          <div className={`feed-media-grid grid-${Math.min(4, displayMedia.length)}`}>
                            {displayMedia.map((url, idx) => {
                              const finalUrl = getMediaUrl(url);
                              const isVideo = /\.(mp4|webm|ogg)(\?.*)?$/.test(finalUrl);
                              return (
                                <div key={idx} className="media-item-wrapper" onClick={() => setLightboxIndex(idx)}>
                                  {isVideo ? (
                                    <video src={finalUrl} className="media-item" controls preload="metadata" />
                                  ) : (
                                    <img src={finalUrl} alt="" className="media-item" loading="lazy" />
                                  )}
                                </div>
                              );
                            })}
                          </div>
                        )}
                      </div>
                    )}
              </div>

              <div className="comments-list">
                {comments === null && <div>Đang tải bình luận…</div>}
                {comments && comments.length === 0 && <div>Chưa có bình luận nào</div>}
                {comments && comments.map(c => (
                  <div key={c.commentId} className="comment-row">
                    <UserAvatar imageUrl={userMap[c.authorId]?.avatarUrl ?? null} name={userMap[c.authorId]?.displayName ?? c.authorId} size="sm" />
                    <div className="comment-body">
                      <div className="comment-row-header">
                        <div className="comment-author-wrap">
                          <div className="comment-author">{userMap[c.authorId]?.displayName ?? c.authorId}</div>
                          <div className="comment-time">{new Date(c.createdAt).toLocaleString()}</div>
                        </div>
                        {canManageComment(c) && (
                          <div className="comment-menu-wrapper">
                            <button
                              type="button"
                              className="comment-menu-trigger"
                              aria-haspopup="menu"
                              aria-expanded={activeCommentMenuId === c.commentId}
                              onClick={() => setActiveCommentMenuId(prev => prev === c.commentId ? null : c.commentId)}
                            >
                              <Icon name="more" size={18} />
                            </button>
                            {activeCommentMenuId === c.commentId && (
                              <div className="post-menu comment-menu" role="menu">
                                {canEditComment(c) && (
                                  <button
                                    type="button"
                                    className="post-menu-item"
                                    role="menuitem"
                                    onClick={() => startEditComment(c)}
                                  >
                                    Chỉnh sửa bình luận
                                  </button>
                                )}
                                <button
                                  type="button"
                                  className="post-menu-item post-menu-item-danger"
                                  role="menuitem"
                                  onClick={() => confirmDeleteComment(c)}
                                >
                                  Xóa bình luận
                                </button>
                              </div>
                            )}
                          </div>
                        )}
                      </div>

                      {editingCommentId === c.commentId ? (
                        <div className="comment-edit-box">
                          <textarea
                            className="comment-input comment-edit-input"
                            value={editingCommentText}
                            onChange={e => setEditingCommentText(e.target.value)}
                            rows={2}
                          />
                          <div className="comment-edit-actions">
                            <button type="button" className="composer-btn" onClick={cancelEditComment}>
                              Hủy
                            </button>
                            <button
                              type="button"
                              className="composer-btn primary"
                              disabled={isSavingCommentEdit || !editingCommentText.trim()}
                              onClick={saveCommentEdit}
                            >
                              {isSavingCommentEdit ? 'Đang lưu…' : 'Lưu'}
                            </button>
                          </div>
                        </div>
                      ) : (
                        <div className="comment-text">{(c as any).contentText ?? (c as any).content}</div>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            </div>
            <div className="social-modal-footer">
              <div className="comment-input-row">
                <div className="comment-compose-shell">
                  <textarea
                    ref={commentInputRef}
                    className="comment-input"
                    placeholder="Viết bình luận..."
                    value={commentInput}
                    onChange={e => setCommentInput(e.target.value)}
                    rows={1}
                  />
                  {isCommentEmojiPickerOpen && (
                    <div className="social-emoji-picker comment-emoji-picker" role="group" aria-label="Chọn emoji cho bình luận">
                      {emojiOptions.map((emoji, idx) => (
                        <button
                          key={`${emoji}-${idx}`}
                          type="button"
                          className="social-emoji-option"
                          onClick={() => insertCommentEmoji(emoji)}
                          aria-label={`Chèn ${emoji}`}
                        >
                          {emoji}
                        </button>
                      ))}
                    </div>
                  )}
                </div>
                <button className="composer-btn primary" disabled={isPostingComment || !commentInput.trim()} onClick={async () => {
                  if (!accessToken) return;
                  setIsPostingComment(true);
                  try {
                    const created = await socialApi.createComment(accessToken, post.postId, commentInput.trim());
                    // prepend optimistic
                    setComments(prev => prev ? [created, ...prev] : [created]);
                    setCommentInput('');
                    setIsCommentEmojiPickerOpen(false);
                    // notify parent to update comment count
                    onCommentCreated(post.postId, (post.commentCount || 0) + 1);
                  } catch (e) {
                    console.error('Create comment failed', e);
                  } finally {
                    setIsPostingComment(false);
                  }
                }}>{isPostingComment ? 'Đang gửi…' : 'Gửi'}</button>
                <button type="button" className="composer-btn" title="Thêm emoji" onClick={() => setIsCommentEmojiPickerOpen(prev => !prev)} aria-pressed={isCommentEmojiPickerOpen}>
                  <Icon name="smile" size={20} />
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {commentToDelete && (
        <div className="social-modal-overlay social-confirm-overlay" onClick={() => setCommentToDelete(null)}>
          <div className="social-confirm-modal" onClick={e => e.stopPropagation()}>
            <div className="social-confirm-header">
              <h3>Xóa bình luận</h3>
              <button type="button" className="composer-btn" onClick={() => setCommentToDelete(null)} style={{ padding: '4px' }}>
                <Icon name="close" size={20} />
              </button>
            </div>
            <div className="social-confirm-body">
              <p>Bạn có chắc muốn xóa bình luận này không? Hành động này không thể hoàn tác.</p>
            </div>
            <div className="social-confirm-footer">
              <button type="button" className="composer-btn" onClick={() => setCommentToDelete(null)}>
                Hủy
              </button>
              <button type="button" className="composer-btn primary" onClick={handleDeleteComment} disabled={isDeletingComment}>
                {isDeletingComment ? 'Đang xóa...' : 'Xóa bình luận'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
