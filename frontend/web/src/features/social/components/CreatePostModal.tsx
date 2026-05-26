import { useEffect, useRef, useState } from 'react';
import { socialApi, uploadSocialMedia, type Post } from '../api/social.api';
import { resizeImageFile } from '../../../utils/image';
import { Icon } from '../../../shared/components/Icon';
import { UserAvatar } from '../../../shared/components/UserAvatar';
import { REACTION_OPTIONS } from '../../chat/chat.constants';

interface CreatePostModalProps {
  isOpen: boolean;
  onClose: () => void;
  onPostCreated: (post: Post) => void;
  onPostUpdated?: (post: Post) => void;
  accessToken: string | null;
  currentUserProfile: { displayName: string; avatarUrl: string | null } | null;
  editingPost?: Post | null;
}

export function CreatePostModal({
  isOpen,
  onClose,
  onPostCreated,
  onPostUpdated,
  accessToken,
  currentUserProfile,
  editingPost,
}: CreatePostModalProps) {
  const isEditMode = Boolean(editingPost);
  const [content, setContent] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isUploadingMedia, setIsUploadingMedia] = useState(false);
  const [isEmojiPickerOpen, setIsEmojiPickerOpen] = useState(false);
  const [visibility, setVisibility] = useState('PUBLIC');
  const [mediaUrls, setMediaUrls] = useState<string[]>([]);
  const [error, setError] = useState<string | null>(null);
  const textareaRef = useRef<HTMLTextAreaElement | null>(null);
  const fileInputRef = useRef<HTMLInputElement | null>(null);

  useEffect(() => {
    if (!isOpen) return;

    setContent(editingPost?.contentText ?? '');
    setVisibility((editingPost?.visibility as string) ?? 'PUBLIC');
    setMediaUrls(editingPost?.mediaUrls ? [...editingPost.mediaUrls] : []);
    setError(null);
    setIsEmojiPickerOpen(false);
  }, [editingPost, isOpen]);

  if (!isOpen) return null;

  const emojiOptions = [...REACTION_OPTIONS.map(item => item.emoji), '😊', '🥳', '✨', '💖', '😄', '🤩', '🙌', '🔥'];

  const insertEmoji = (emoji: string) => {
    setContent(prev => {
      const textarea = textareaRef.current;
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

  const handlePickMedia = () => {
    fileInputRef.current?.click();
  };

  // Video limits
  const MAX_VIDEO_BYTES = 50 * 1024 * 1024; // 50 MB
  const MAX_VIDEO_SECONDS = 60; // 60 seconds

  const getVideoDuration = (file: File): Promise<number> => {
    return new Promise((resolve, reject) => {
      try {
        const url = URL.createObjectURL(file);
        const video = document.createElement('video');
        let settled = false;
        const cleanup = () => {
          try { URL.revokeObjectURL(url); } catch {
            /* ignore */
          }
          video.removeAttribute('src');
          video.load();
        };

        video.preload = 'metadata';
        video.src = url;
        video.onloadedmetadata = () => {
          if (settled) return;
          settled = true;
          const d = video.duration;
          cleanup();
          resolve(d);
        };
        video.onerror = () => {
          if (settled) return;
          settled = true;
          cleanup();
          reject(new Error('Failed to load video metadata'));
        };
      } catch (err) {
        reject(err);
      }
    });
  };

  const handleMediaInputChange = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(event.target.files ?? []).filter(file => file.type.startsWith('image/') || file.type.startsWith('video/'));
    event.target.value = '';

    if (files.length === 0) {
      return;
    }

    // Validate video size and duration before uploading
    const validFiles: File[] = [];
    const rejectedReasons: string[] = [];

    for (const file of files) {
      if (file.type.startsWith('video/')) {
        if (file.size > MAX_VIDEO_BYTES) {
          rejectedReasons.push(`${file.name}: kích thước quá lớn (>${Math.round(MAX_VIDEO_BYTES / (1024 * 1024))} MB)`);
          continue;
        }

        try {
          const duration = await getVideoDuration(file);
          if (duration > MAX_VIDEO_SECONDS) {
            rejectedReasons.push(`${file.name}: thời lượng quá dài (${Math.round(duration)}s > ${MAX_VIDEO_SECONDS}s)`);
            continue;
          }
        } catch {
          // If we can't read metadata, reject to be safe
          rejectedReasons.push(`${file.name}: không thể đọc metadata video`);
          continue;
        }
      }

      validFiles.push(file);
    }

    if (rejectedReasons.length > 0) {
      setError(`Một số file bị bỏ: ${rejectedReasons.join('; ')}`);
    }

    if (!accessToken) {
      setError('Bạn cần đăng nhập để tải ảnh lên.');
      return;
    }

    if (validFiles.length === 0) {
      // nothing to upload
      return;
    }

    setIsUploadingMedia(true);
    if (rejectedReasons.length === 0) {
      setError(null);
    }

    try {
      const uploadedUrls = await Promise.all(
        validFiles.map(async file => {
          try {
            if (file.type.startsWith('image/')) {
              const resized = await resizeImageFile(file, 1280, 1280, 0.8);
              return await uploadSocialMedia(accessToken, resized);
            }
            // video: upload directly
            return await uploadSocialMedia(accessToken, file);
          } catch (e) {
            console.warn('[CreatePost] resize or upload failed for file', file.name, e);
            return await uploadSocialMedia(accessToken, file);
          }
        }),
      );
      setMediaUrls(prev => [...prev, ...uploadedUrls]);
    } catch (uploadError) {
      console.error('[CreatePost] Media upload failed:', uploadError);
      setError('Không thể tải ảnh lên. Vui lòng thử lại.');
    } finally {
      setIsUploadingMedia(false);
    }
  };

  const buildOptimisticPost = (): Post => ({
    postId: `local-${Date.now()}`,
    authorId: 'Tôi',
    contentText: content,
    mediaUrls,
    visibility,
    likeCount: 0,
    commentCount: 0,
    shareCount: 0,
    status: 'ACTIVE',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  });

  const handleSubmit = async () => {
    if (!content.trim() && mediaUrls.length === 0) return;
    setIsSubmitting(true);
    setError(null);

    try {
      if (!accessToken) {
        throw new Error('Missing access token');
      }

      const optimisticPost = buildOptimisticPost();

      if (isEditMode && editingPost) {
        const updatedPost: Post = { ...editingPost, ...optimisticPost, postId: editingPost.postId };
        // optimistic update immediately
        onPostUpdated?.(updatedPost);
        onClose();
        setContent('');
        setMediaUrls([]);
        setIsEmojiPickerOpen(false);

        // log payload for debugging why some media might be missing
        console.debug('[CreatePost] update payload mediaUrls:', updatedPost.mediaUrls);

        const saved = await socialApi.updatePost(accessToken, editingPost.postId, {
          contentText: updatedPost.contentText,
          mediaUrls: updatedPost.mediaUrls,
          visibility: updatedPost.visibility,
        });

        console.debug('[CreatePost] update response:', saved);

        // replace optimistic post with server-canonical post if available
        if (saved) {
          try {
            // saved is expected to be the PostResponse shape
            onPostUpdated?.(saved as unknown as Post);
          } catch (err) {
            console.warn('[CreatePost] failed to apply saved post to UI', err);
          }
        }
      } else {
        onPostCreated(optimisticPost);
        onClose();
        setContent('');
        setMediaUrls([]);
        setIsEmojiPickerOpen(false);

        const created = await socialApi.createPost(accessToken, {
          contentText: optimisticPost.contentText,
          mediaUrls: optimisticPost.mediaUrls,
          visibility: optimisticPost.visibility,
        });

        console.debug('[CreatePost] create response:', created);
        if (created) {
          try {
            onPostCreated(created as unknown as Post);
          } catch (err) {
            console.warn('[CreatePost] failed to apply created post to UI', err);
          }
        }
      }
    } catch (e) {
      // Mạng lỗi — bài viết vẫn hiển thị nhờ optimistic UI, chỉ warn log
      console.warn('[CreatePost] Network error, post shown optimistically only:', e);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="social-modal-overlay" onClick={onClose}>
      <div className="social-modal-content" onClick={e => e.stopPropagation()}>
        <div className="social-modal-header">
          <h3>{isEditMode ? 'Chỉnh sửa bài viết' : 'Tạo bài viết'}</h3>
          <button type="button" className="composer-btn" onClick={onClose} style={{ padding: '4px' }}>
            <Icon name="close" size={24} />
          </button>
        </div>

        <div className="social-modal-body">
          <div className="post-author-info">
            <UserAvatar
              imageUrl={currentUserProfile?.avatarUrl ?? null}
              name={currentUserProfile?.displayName ?? 'Tôi'}
              size="md"
            />
            <div className="post-author-details">
              <span className="post-author-name">{currentUserProfile?.displayName ?? 'Tôi'}</span>
              <select
                value={visibility}
                onChange={e => setVisibility(e.target.value)}
                style={{ marginTop: '4px', padding: '2px 8px', borderRadius: '6px', border: '1px solid var(--color-border)', background: 'var(--color-surface)', color: 'var(--color-text-primary)', fontSize: '13px' }}
              >
                <option value="PUBLIC">🌐 Công khai</option>
                <option value="FRIENDS">👥 Bạn bè</option>
                <option value="PRIVATE">🔒 Chỉ mình tôi</option>
              </select>
            </div>
          </div>

          <textarea
            ref={textareaRef}
            className="create-post-textarea"
            placeholder="Bạn đang nghĩ gì?"
            value={content}
            onChange={e => setContent(e.target.value)}
            autoFocus
          />

          {mediaUrls.length > 0 && (
            <div className="create-post-media-preview">
              {mediaUrls.map((url, idx) => (
                    <div key={idx} className="media-preview-item">
                      {/\.(mp4|webm|ogg)(\?.*)?$/i.test(url) ? (
                        <video src={url} controls />
                      ) : (
                        <img src={url} alt="preview" />
                      )}
                      <button
                        type="button"
                        className="media-preview-remove"
                        onClick={() => setMediaUrls(prev => prev.filter((_, i) => i !== idx))}
                      >
                        <Icon name="close" size={16} />
                      </button>
                    </div>
                  ))}
            </div>
          )}

          {isEmojiPickerOpen && (
            <div className="social-emoji-picker" role="group" aria-label="Chọn emoji">
              {emojiOptions.map((emoji, idx) => (
                <button
                  key={`${emoji}-${idx}`}
                  type="button"
                  className="social-emoji-option"
                  onClick={() => insertEmoji(emoji)}
                  aria-label={`Chèn ${emoji}`}
                >
                  {emoji}
                </button>
              ))}
            </div>
          )}

          {error && (
            <p style={{ color: 'var(--color-danger, #ef4444)', fontSize: '13px', margin: 0 }}>
              ⚠️ {error}
            </p>
          )}
        </div>

        <div className="social-modal-footer">
          <div className="social-modal-actions">
            <div className="social-modal-toolbar">
              <button type="button" className="composer-btn" title="Thêm Ảnh/Video" onClick={handlePickMedia} disabled={isUploadingMedia || isSubmitting}>
                <Icon name="image" size={20} /> {isUploadingMedia ? 'Đang tải...' : 'Ảnh/Video'}
              </button>
              <button
                type="button"
                className="composer-btn"
                title="Thêm emoji"
                onClick={() => setIsEmojiPickerOpen(prev => !prev)}
                aria-pressed={isEmojiPickerOpen}
              >
                <Icon name="smile" size={20} /> Emoji
              </button>
              <input
                ref={fileInputRef}
                className="social-upload-input"
                type="file"
                accept="image/*,video/*"
                multiple
                onChange={handleMediaInputChange}
              />
            </div>
            <button className="composer-btn primary" type="button" onClick={handleSubmit} disabled={isSubmitting || isUploadingMedia || (!content.trim() && mediaUrls.length === 0)}>
              {isSubmitting ? (isEditMode ? 'Đang lưu...' : 'Đang đăng...') : (isEditMode ? 'Lưu thay đổi' : 'Đăng bài')}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

