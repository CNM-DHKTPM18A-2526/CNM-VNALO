# Complete Database Schema - OTT Zalo Clone

> **Version**: 3.0 - Full Zalo Features (16 Services)  
> **Last Updated**: January 16, 2026  
> **Database**: PostgreSQL (primary) + Cassandra (messages)

---

## 1. Auth Service Database

### 1.1 `auth_account`
```sql
CREATE TABLE auth_account (
    account_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone VARCHAR(20) NOT NULL UNIQUE,
    firebase_uid VARCHAR(128) UNIQUE,
    password_hash VARCHAR(255),
    status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'LOCKED', 'DISABLED', 'DELETED')),
    locked_until TIMESTAMP,
    failed_login_count INT DEFAULT 0,
    last_login_at TIMESTAMP,
    last_login_device_id VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_auth_account_phone ON auth_account(phone);
CREATE INDEX idx_auth_account_status ON auth_account(status);
```

### 1.2 `auth_refresh_token`
```sql
CREATE TABLE auth_refresh_token (
    token_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL,
    token_hash VARCHAR(255) NOT NULL UNIQUE,
    device_id VARCHAR(100) NOT NULL,
    device_name VARCHAR(100),
    platform VARCHAR(20) CHECK (platform IN ('ANDROID', 'IOS', 'WEB', 'PC')),
    ip_address VARCHAR(45),
    user_agent TEXT,
    expires_at TIMESTAMP NOT NULL,
    revoked_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_refresh_token_account ON auth_refresh_token(account_id, expires_at);
CREATE INDEX idx_refresh_token_device ON auth_refresh_token(device_id);
```

### 1.3 `auth_otp`
```sql
CREATE TABLE auth_otp (
    otp_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    target VARCHAR(50) NOT NULL,
    purpose VARCHAR(30) CHECK (purpose IN ('REGISTER', 'LOGIN', 'RESET_PASSWORD', 'VERIFY_DEVICE', 'CHANGE_PHONE')),
    otp_hash VARCHAR(255) NOT NULL,
    attempts INT DEFAULT 0,
    max_attempts INT DEFAULT 5,
    expires_at TIMESTAMP NOT NULL,
    verified_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_otp_target ON auth_otp(target, purpose, created_at DESC);
```

---

## 2. User Profile Service Database

### 2.1 `user_profile`
```sql
CREATE TABLE user_profile (
    user_id UUID PRIMARY KEY,
    display_name VARCHAR(100) NOT NULL,
    avatar_url VARCHAR(500),
    cover_url VARCHAR(500),
    bio VARCHAR(500),
    gender VARCHAR(20) DEFAULT 'UNKNOWN' CHECK (gender IN ('UNKNOWN', 'MALE', 'FEMALE', 'OTHER')),
    date_of_birth DATE,
    region VARCHAR(100),
    status_message VARCHAR(200),
    qr_code_url VARCHAR(500),
    is_verified BOOLEAN DEFAULT FALSE,
    is_official_account BOOLEAN DEFAULT FALSE,
    follower_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_profile_name ON user_profile(display_name);
CREATE INDEX idx_profile_verified ON user_profile(is_verified) WHERE is_verified = TRUE;
```

### 2.2 `user_privacy_setting`
```sql
CREATE TABLE user_privacy_setting (
    user_id UUID PRIMARY KEY,
    allow_search_by_phone BOOLEAN DEFAULT TRUE,
    allow_search_by_qr BOOLEAN DEFAULT TRUE,
    allow_stranger_message BOOLEAN DEFAULT FALSE,
    allow_friend_request BOOLEAN DEFAULT TRUE,
    show_online_status BOOLEAN DEFAULT TRUE,
    last_seen_visibility VARCHAR(20) DEFAULT 'FRIENDS' CHECK (last_seen_visibility IN ('EVERYONE', 'FRIENDS', 'NOBODY')),
    story_visibility VARCHAR(20) DEFAULT 'FRIENDS' CHECK (story_visibility IN ('EVERYONE', 'FRIENDS', 'CUSTOM', 'CLOSE_FRIENDS')),
    timeline_visibility VARCHAR(20) DEFAULT 'FRIENDS' CHECK (timeline_visibility IN ('EVERYONE', 'FRIENDS', 'ONLY_ME')),
    allow_add_to_group VARCHAR(20) DEFAULT 'FRIENDS' CHECK (allow_add_to_group IN ('EVERYONE', 'FRIENDS', 'NOBODY')),
    allow_voice_call VARCHAR(20) DEFAULT 'FRIENDS' CHECK (allow_voice_call IN ('EVERYONE', 'FRIENDS', 'NOBODY')),
    allow_video_call VARCHAR(20) DEFAULT 'FRIENDS' CHECK (allow_video_call IN ('EVERYONE', 'FRIENDS', 'NOBODY')),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
```

### 2.3 `user_setting`
```sql
CREATE TABLE user_setting (
    user_id UUID PRIMARY KEY,
    language VARCHAR(10) DEFAULT 'vi',
    theme VARCHAR(20) DEFAULT 'LIGHT' CHECK (theme IN ('LIGHT', 'DARK', 'SYSTEM')),
    font_size VARCHAR(20) DEFAULT 'MEDIUM' CHECK (font_size IN ('SMALL', 'MEDIUM', 'LARGE')),
    notification_sound BOOLEAN DEFAULT TRUE,
    notification_vibrate BOOLEAN DEFAULT TRUE,
    notification_preview BOOLEAN DEFAULT TRUE,
    auto_download_image BOOLEAN DEFAULT TRUE,
    auto_download_video BOOLEAN DEFAULT FALSE,
    auto_download_file BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
```

---

## 3. Social Graph Service Database

### 3.1 `friend_request`
```sql
CREATE TABLE friend_request (
    request_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_user_id UUID NOT NULL,
    to_user_id UUID NOT NULL,
    message VARCHAR(200),
    source VARCHAR(30) CHECK (source IN ('SEARCH', 'QR', 'CONTACT_SYNC', 'SUGGEST', 'GROUP', 'NEARBY')),
    status VARCHAR(20) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'ACCEPTED', 'DECLINED', 'CANCELED')),
    responded_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT unique_pending_request UNIQUE (from_user_id, to_user_id, status)
);

CREATE INDEX idx_friend_req_to ON friend_request(to_user_id, status, created_at DESC);
CREATE INDEX idx_friend_req_from ON friend_request(from_user_id, status, created_at DESC);
```

### 3.2 `friendship`
```sql
CREATE TABLE friendship (
    friendship_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id_1 UUID NOT NULL,
    user_id_2 UUID NOT NULL,
    source VARCHAR(30),
    nickname_1_for_2 VARCHAR(50),
    nickname_2_for_1 VARCHAR(50),
    is_favorite_1 BOOLEAN DEFAULT FALSE,
    is_favorite_2 BOOLEAN DEFAULT FALSE,
    is_hidden_1 BOOLEAN DEFAULT FALSE,
    is_hidden_2 BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT unique_friendship UNIQUE (user_id_1, user_id_2),
    CONSTRAINT ordered_users CHECK (user_id_1 < user_id_2)
);

CREATE INDEX idx_friendship_user1 ON friendship(user_id_1);
CREATE INDEX idx_friendship_user2 ON friendship(user_id_2);
CREATE INDEX idx_friendship_favorite1 ON friendship(user_id_1) WHERE is_favorite_1 = TRUE;
CREATE INDEX idx_friendship_favorite2 ON friendship(user_id_2) WHERE is_favorite_2 = TRUE;
```

### 3.3 `block_list`
```sql
CREATE TABLE block_list (
    block_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blocker_id UUID NOT NULL,
    blocked_id UUID NOT NULL,
    reason VARCHAR(30) CHECK (reason IN ('SPAM', 'HARASSMENT', 'INAPPROPRIATE', 'SCAM', 'OTHER')),
    note VARCHAR(200),
    created_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT unique_block UNIQUE (blocker_id, blocked_id)
);

CREATE INDEX idx_block_blocker ON block_list(blocker_id);
CREATE INDEX idx_block_blocked ON block_list(blocked_id);
```

### 3.4 `contact_sync`
```sql
CREATE TABLE contact_sync (
    sync_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    phone_number VARCHAR(20) NOT NULL,
    contact_name VARCHAR(100),
    matched_user_id UUID,
    invited_at TIMESTAMP,
    synced_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT unique_contact UNIQUE (user_id, phone_number)
);

CREATE INDEX idx_contact_user ON contact_sync(user_id);
CREATE INDEX idx_contact_matched ON contact_sync(matched_user_id) WHERE matched_user_id IS NOT NULL;
```

---

## 4. Conversation Service Database

### 4.1 `conversation`
```sql
-- Note: last_message metadata is managed via CQRS in conversation_inbox table
CREATE TABLE conversation (
    conversation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type VARCHAR(20) NOT NULL CHECK (type IN ('DIRECT', 'GROUP')),
    title VARCHAR(100),
    avatar_url VARCHAR(500),
    description VARCHAR(500),
    created_by UUID NOT NULL,
    status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'ARCHIVED', 'DISABLED')),
    join_mode VARCHAR(20) DEFAULT 'INVITE_ONLY' CHECK (join_mode IN ('OPEN', 'APPROVAL', 'INVITE_ONLY')),
    member_limit INT DEFAULT 1000,
    invite_link VARCHAR(100) UNIQUE,
    invite_link_expires_at TIMESTAMPTZ,
    is_encrypted BOOLEAN DEFAULT FALSE,
    allow_member_invite BOOLEAN DEFAULT TRUE,
    allow_member_pin BOOLEAN DEFAULT FALSE,
    allow_member_edit_info BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_conv_type ON conversation(type);
CREATE INDEX idx_conv_invite_link ON conversation(invite_link) WHERE invite_link IS NOT NULL;
```

### 4.2 `conversation_member`
```sql
CREATE TABLE conversation_member (
    conversation_id UUID NOT NULL,
    user_id UUID NOT NULL,
    role VARCHAR(20) DEFAULT 'MEMBER' CHECK (role IN ('OWNER', 'ADMIN', 'MEMBER')),
    nickname VARCHAR(50),
    joined_at TIMESTAMP DEFAULT NOW(),
    joined_by UUID,
    left_at TIMESTAMP,
    removed_by UUID,
    mute_until TIMESTAMP,
    is_pinned BOOLEAN DEFAULT FALSE,
    pin_order INT,
    is_hidden BOOLEAN DEFAULT FALSE,
    last_read_seq BIGINT DEFAULT 0,
    last_read_at TIMESTAMP,
    notification_setting VARCHAR(20) DEFAULT 'ALL' CHECK (notification_setting IN ('ALL', 'MENTIONS', 'NONE')),
    PRIMARY KEY (conversation_id, user_id)
);

CREATE INDEX idx_conv_member_user ON conversation_member(user_id, is_pinned DESC, left_at) WHERE left_at IS NULL;
CREATE INDEX idx_conv_member_conv ON conversation_member(conversation_id) WHERE left_at IS NULL;
CREATE INDEX idx_conv_member_pinned ON conversation_member(user_id, pin_order) WHERE is_pinned = TRUE AND left_at IS NULL;
```

### 4.3 `conversation_direct_map`
```sql
CREATE TABLE conversation_direct_map (
    user_id_1 UUID NOT NULL,
    user_id_2 UUID NOT NULL,
    conversation_id UUID NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (user_id_1, user_id_2),
    CONSTRAINT ordered_direct_users CHECK (user_id_1 < user_id_2)
);

CREATE INDEX idx_direct_map_conv ON conversation_direct_map(conversation_id);
```

### 4.4 `group_join_request`
```sql
CREATE TABLE group_join_request (
    request_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL,
    user_id UUID NOT NULL,
    message VARCHAR(200),
    status VARCHAR(20) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
    reviewed_by UUID,
    reviewed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_group_join_conv ON group_join_request(conversation_id, status);
```

### 4.5 `group_banned_member`
```sql
CREATE TABLE group_banned_member (
    conversation_id UUID NOT NULL,
    user_id UUID NOT NULL,
    banned_by UUID NOT NULL,
    reason VARCHAR(200),
    banned_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    PRIMARY KEY (conversation_id, user_id)
);
```

### 4.6 `conversation_inbox` (CQRS Read Model)
```sql
-- CQRS read model: Message Service owns source-of-truth for messages
-- This table is updated via Kafka event 'conversation_metadata_updated'
CREATE TABLE conversation_inbox (
    user_id UUID NOT NULL,
    conversation_id UUID NOT NULL,
    last_message_seq BIGINT NOT NULL DEFAULT 0,
    last_message_at TIMESTAMPTZ,
    last_message_preview VARCHAR(200),
    last_message_sender_id UUID,
    last_message_type VARCHAR(30),
    unread_count INT NOT NULL DEFAULT 0,
    is_pinned BOOLEAN DEFAULT FALSE,
    is_muted BOOLEAN DEFAULT FALSE,
    is_hidden BOOLEAN DEFAULT FALSE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, conversation_id)
);

-- Main query: list user's conversations sorted by last message
CREATE INDEX idx_inbox_user_sort 
    ON conversation_inbox(user_id, is_pinned DESC, last_message_seq DESC);
-- Query: unread count
CREATE INDEX idx_inbox_unread 
    ON conversation_inbox(user_id, unread_count) WHERE unread_count > 0;
```

---

## 5. Message Service Database

### 5.1 `message` (Cassandra - Production)
```cql
CREATE TABLE messages_by_conversation (
    conversation_id UUID,
    server_seq BIGINT,
    message_id UUID,
    sender_id UUID,
    client_message_id UUID,
    message_type TEXT,  -- TEXT/IMAGE/VIDEO/FILE/VOICE/STICKER/GIF/LOCATION/CONTACT/LINK/SYSTEM/POLL/FORWARD
    content TEXT,
    media_id UUID,
    sticker_id UUID,
    reply_to_message_id UUID,
    reply_to_seq BIGINT,
    forward_from_message_id UUID,
    forward_from_conversation_id UUID,
    mentions SET<UUID>,
    status TEXT,  -- SENT/DELETED/REVOKED
    is_edited BOOLEAN,
    edited_at TIMESTAMP,
    server_ts TIMESTAMP,
    expires_at TIMESTAMP,  -- For disappearing messages
    PRIMARY KEY ((conversation_id), server_seq)
) WITH CLUSTERING ORDER BY (server_seq DESC);
```

### 5.2 `message` (PostgreSQL - MVP)
```sql
CREATE TABLE message (
    message_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL,
    server_seq BIGINT NOT NULL,
    sender_id UUID NOT NULL,
    client_message_id UUID NOT NULL,
    message_type VARCHAR(30) NOT NULL CHECK (message_type IN (
        'TEXT', 'IMAGE', 'VIDEO', 'FILE', 'VOICE', 'STICKER', 'GIF', 
        'LOCATION', 'CONTACT', 'LINK', 'SYSTEM', 'POLL', 'FORWARD'
    )),
    content TEXT,
    media_id UUID,
    sticker_id UUID,
    reply_to_message_id UUID,
    reply_to_seq BIGINT,
    forward_from_message_id UUID,
    forward_from_conversation_id UUID,
    mentions UUID[],
    status VARCHAR(20) DEFAULT 'SENT' CHECK (status IN ('SENT', 'DELETED', 'REVOKED')),
    is_edited BOOLEAN DEFAULT FALSE,
    edited_at TIMESTAMP,
    server_ts TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT unique_msg_seq UNIQUE (conversation_id, server_seq)
);

CREATE INDEX idx_msg_conv_seq ON message(conversation_id, server_seq DESC);
CREATE UNIQUE INDEX idx_msg_idempotency ON message(sender_id, client_message_id);
CREATE INDEX idx_msg_reply ON message(reply_to_message_id) WHERE reply_to_message_id IS NOT NULL;
```

### 5.3 `message_idempotency_by_sender` (Cassandra)
```cql
CREATE TABLE message_idempotency_by_sender (
    sender_id UUID,
    client_message_id UUID,
    conversation_id UUID,
    server_seq BIGINT,
    message_id UUID,
    created_at TIMESTAMP,
    PRIMARY KEY ((sender_id), client_message_id)
) WITH default_time_to_live = 604800;  -- 7 days TTL
```

### 5.4 `message_reaction`
```sql
CREATE TABLE message_reaction (
    reaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL,
    message_id UUID NOT NULL,
    user_id UUID NOT NULL,
    emoji VARCHAR(20) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT unique_reaction UNIQUE (message_id, user_id)
);

CREATE INDEX idx_reaction_msg ON message_reaction(message_id);
CREATE INDEX idx_reaction_conv ON message_reaction(conversation_id);
```

### 5.5 `message_receipt`
```sql
CREATE TABLE message_receipt (
    conversation_id UUID NOT NULL,
    message_id UUID NOT NULL,
    user_id UUID NOT NULL,
    delivered_at TIMESTAMP,
    seen_at TIMESTAMP,
    PRIMARY KEY (conversation_id, message_id, user_id)
);

CREATE INDEX idx_receipt_user ON message_receipt(user_id, seen_at DESC);
```

### 5.6 `pinned_message`
```sql
CREATE TABLE pinned_message (
    pin_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL,
    message_id UUID NOT NULL,
    server_seq BIGINT NOT NULL,
    pinned_by UUID NOT NULL,
    pinned_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT unique_pinned_msg UNIQUE (conversation_id, message_id)
);

CREATE INDEX idx_pinned_conv ON pinned_message(conversation_id, pinned_at DESC);
```

### 5.7 `poll`
```sql
CREATE TABLE poll (
    poll_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL,
    message_id UUID NOT NULL,
    creator_id UUID NOT NULL,
    question TEXT NOT NULL,
    allow_multiple BOOLEAN DEFAULT FALSE,
    allow_add_option BOOLEAN DEFAULT FALSE,
    is_anonymous BOOLEAN DEFAULT FALSE,
    expires_at TIMESTAMP,
    status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'CLOSED')),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE poll_option (
    option_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    poll_id UUID NOT NULL,
    text VARCHAR(200) NOT NULL,
    created_by UUID NOT NULL,
    vote_count INT DEFAULT 0,
    option_order INT NOT NULL
);

CREATE TABLE poll_vote (
    poll_id UUID NOT NULL,
    option_id UUID NOT NULL,
    user_id UUID NOT NULL,
    voted_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (poll_id, option_id, user_id)
);
```

---

## 6. Media Service Database

### 6.1 `media_object`
```sql
CREATE TABLE media_object (
    media_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL,
    bucket VARCHAR(50) NOT NULL,
    object_key VARCHAR(500) NOT NULL,
    url VARCHAR(500),
    thumbnail_url VARCHAR(500),
    mime_type VARCHAR(100) NOT NULL,
    size_bytes BIGINT NOT NULL,
    checksum VARCHAR(64),
    width INT,
    height INT,
    duration_ms INT,
    original_filename VARCHAR(255),
    media_category VARCHAR(30) CHECK (media_category IN (
        'AVATAR', 'COVER', 'CHAT_IMAGE', 'CHAT_VIDEO', 'CHAT_FILE', 
        'CHAT_VOICE', 'STORY', 'TIMELINE', 'STICKER'
    )),
    status VARCHAR(20) DEFAULT 'UPLOADING' CHECK (status IN ('UPLOADING', 'PROCESSING', 'READY', 'FAILED', 'DELETED')),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_media_owner ON media_object(owner_user_id, created_at DESC);
CREATE INDEX idx_media_status ON media_object(status);
CREATE INDEX idx_media_category ON media_object(media_category, created_at DESC);
```

### 6.2 `media_access_scope`
```sql
CREATE TABLE media_access_scope (
    media_id UUID NOT NULL,
    scope_type VARCHAR(20) NOT NULL CHECK (scope_type IN ('CONVERSATION', 'USER', 'PUBLIC')),
    scope_id UUID NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (media_id, scope_type, scope_id)
);
```

---

## 7. Call Service Database

### 7.1 `call_session`
```sql
CREATE TABLE call_session (
    call_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL,
    call_type VARCHAR(20) NOT NULL CHECK (call_type IN ('VOICE', 'VIDEO', 'GROUP_VOICE', 'GROUP_VIDEO')),
    initiator_id UUID NOT NULL,
    status VARCHAR(20) DEFAULT 'RINGING' CHECK (status IN ('RINGING', 'ONGOING', 'ENDED', 'MISSED', 'DECLINED', 'BUSY', 'FAILED')),
    started_at TIMESTAMP DEFAULT NOW(),
    connected_at TIMESTAMP,
    ended_at TIMESTAMP,
    duration_seconds INT,
    end_reason VARCHAR(30) CHECK (end_reason IN ('NORMAL', 'TIMEOUT', 'NETWORK_ERROR', 'DECLINED', 'BUSY', 'CANCELED'))
);

CREATE INDEX idx_call_conv ON call_session(conversation_id, started_at DESC);
CREATE INDEX idx_call_initiator ON call_session(initiator_id, started_at DESC);
```

### 7.2 `call_participant`
```sql
CREATE TABLE call_participant (
    call_id UUID NOT NULL,
    user_id UUID NOT NULL,
    role VARCHAR(20) DEFAULT 'CALLEE' CHECK (role IN ('CALLER', 'CALLEE')),
    status VARCHAR(20) DEFAULT 'RINGING' CHECK (status IN ('RINGING', 'CONNECTED', 'LEFT', 'DECLINED', 'MISSED')),
    joined_at TIMESTAMP,
    left_at TIMESTAMP,
    is_video_enabled BOOLEAN DEFAULT FALSE,
    is_audio_enabled BOOLEAN DEFAULT TRUE,
    is_screen_sharing BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (call_id, user_id)
);

CREATE INDEX idx_call_part_user ON call_participant(user_id, joined_at DESC);
```

---

## 8. Story Service Database (Zalo Nhật ký)

### 8.1 `story`
```sql
CREATE TABLE story (
    story_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    media_id UUID,
    content_type VARCHAR(20) NOT NULL CHECK (content_type IN ('IMAGE', 'VIDEO', 'TEXT')),
    text_content VARCHAR(500),
    background_color VARCHAR(10),
    font_style VARCHAR(50),
    music_id UUID,
    music_start_ms INT,
    duration_seconds INT DEFAULT 5,
    visibility VARCHAR(20) DEFAULT 'FRIENDS' CHECK (visibility IN ('EVERYONE', 'FRIENDS', 'CUSTOM', 'CLOSE_FRIENDS', 'ONLY_ME')),
    allow_reactions BOOLEAN DEFAULT TRUE,
    allow_replies BOOLEAN DEFAULT TRUE,
    view_count INT DEFAULT 0,
    reaction_count INT DEFAULT 0,
    reply_count INT DEFAULT 0,
    expires_at TIMESTAMP NOT NULL,
    is_highlight BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_story_user ON story(user_id, created_at DESC);
CREATE INDEX idx_story_expires ON story(expires_at DESC);
CREATE INDEX idx_story_highlight ON story(user_id) WHERE is_highlight = TRUE;
```

### 8.2 `story_view`
```sql
CREATE TABLE story_view (
    story_id UUID NOT NULL,
    viewer_id UUID NOT NULL,
    viewed_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (story_id, viewer_id)
);

CREATE INDEX idx_story_view_viewer ON story_view(viewer_id, viewed_at DESC);
```

### 8.3 `story_reaction`
```sql
CREATE TABLE story_reaction (
    reaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    story_id UUID NOT NULL,
    user_id UUID NOT NULL,
    emoji VARCHAR(20) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT unique_story_reaction UNIQUE (story_id, user_id)
);
```

### 8.4 `story_reply`
```sql
CREATE TABLE story_reply (
    reply_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    story_id UUID NOT NULL,
    user_id UUID NOT NULL,
    content VARCHAR(500) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_story_reply ON story_reply(story_id, created_at);
```

### 8.5 `story_highlight`
```sql
CREATE TABLE story_highlight (
    highlight_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    title VARCHAR(50) NOT NULL,
    cover_media_id UUID,
    display_order INT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE story_highlight_item (
    highlight_id UUID NOT NULL,
    story_id UUID NOT NULL,
    added_at TIMESTAMP DEFAULT NOW(),
    display_order INT,
    PRIMARY KEY (highlight_id, story_id)
);
```

### 8.6 `close_friend`
```sql
CREATE TABLE close_friend (
    user_id UUID NOT NULL,
    friend_id UUID NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (user_id, friend_id)
);
```

### 8.7 `story_visibility_exclude`
```sql
CREATE TABLE story_visibility_exclude (
    user_id UUID NOT NULL,
    excluded_user_id UUID NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (user_id, excluded_user_id)
);
```

---

## 9. Timeline Service Database (Zalo Newsfeed)

### 9.1 `timeline_post`
```sql
CREATE TABLE timeline_post (
    post_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    content TEXT,
    visibility VARCHAR(20) DEFAULT 'FRIENDS' CHECK (visibility IN ('PUBLIC', 'FRIENDS', 'ONLY_ME', 'CUSTOM')),
    feeling VARCHAR(50),
    location VARCHAR(200),
    location_lat DECIMAL(10, 8),
    location_lng DECIMAL(11, 8),
    background_id UUID,
    check_in_place VARCHAR(200),
    original_post_id UUID,  -- For shared posts
    like_count INT DEFAULT 0,
    comment_count INT DEFAULT 0,
    share_count INT DEFAULT 0,
    status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'HIDDEN', 'DELETED')),
    allow_comments BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_post_user ON timeline_post(user_id, created_at DESC);
CREATE INDEX idx_post_status ON timeline_post(status, created_at DESC);
```

### 9.2 `timeline_post_media`
```sql
CREATE TABLE timeline_post_media (
    post_id UUID NOT NULL,
    media_id UUID NOT NULL,
    order_index INT NOT NULL,
    PRIMARY KEY (post_id, media_id)
);
```

### 9.3 `timeline_like`
```sql
CREATE TABLE timeline_like (
    post_id UUID NOT NULL,
    user_id UUID NOT NULL,
    reaction_type VARCHAR(20) DEFAULT 'LIKE' CHECK (reaction_type IN ('LIKE', 'LOVE', 'HAHA', 'WOW', 'SAD', 'ANGRY')),
    created_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (post_id, user_id)
);

CREATE INDEX idx_like_user ON timeline_like(user_id, created_at DESC);
```

### 9.4 `timeline_comment`
```sql
CREATE TABLE timeline_comment (
    comment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL,
    user_id UUID NOT NULL,
    parent_comment_id UUID,
    content TEXT NOT NULL,
    media_id UUID,
    sticker_id UUID,
    like_count INT DEFAULT 0,
    reply_count INT DEFAULT 0,
    status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'HIDDEN', 'DELETED')),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_comment_post ON timeline_comment(post_id, created_at);
CREATE INDEX idx_comment_parent ON timeline_comment(parent_comment_id) WHERE parent_comment_id IS NOT NULL;
```

### 9.5 `timeline_comment_like`
```sql
CREATE TABLE timeline_comment_like (
    comment_id UUID NOT NULL,
    user_id UUID NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (comment_id, user_id)
);
```

### 9.6 `timeline_tag`
```sql
CREATE TABLE timeline_tag (
    post_id UUID NOT NULL,
    tagged_user_id UUID NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (post_id, tagged_user_id)
);

CREATE INDEX idx_tag_user ON timeline_tag(tagged_user_id);
```

### 9.7 `timeline_background`
```sql
CREATE TABLE timeline_background (
    background_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type VARCHAR(20) CHECK (type IN ('COLOR', 'GRADIENT', 'IMAGE')),
    value VARCHAR(500) NOT NULL,
    thumbnail_url VARCHAR(500),
    is_active BOOLEAN DEFAULT TRUE,
    display_order INT
);
```

---

## 10. Sticker Service Database

### 10.1 `sticker_pack`
```sql
CREATE TABLE sticker_pack (
    pack_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    description VARCHAR(500),
    thumbnail_url VARCHAR(500) NOT NULL,
    banner_url VARCHAR(500),
    author VARCHAR(100),
    category VARCHAR(30) CHECK (category IN ('CUTE', 'FUNNY', 'LOVE', 'GREETING', 'TRENDING', 'AI_GENERATED', 'OFFICIAL', 'CUSTOM')),
    is_premium BOOLEAN DEFAULT FALSE,
    is_animated BOOLEAN DEFAULT FALSE,
    price DECIMAL(10, 2) DEFAULT 0,
    download_count INT DEFAULT 0,
    sticker_count INT DEFAULT 0,
    status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE', 'DELETED')),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_sticker_pack_category ON sticker_pack(category, download_count DESC);
CREATE INDEX idx_sticker_pack_trending ON sticker_pack(download_count DESC) WHERE status = 'ACTIVE';
```

### 10.2 `sticker`
```sql
CREATE TABLE sticker (
    sticker_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pack_id UUID NOT NULL,
    name VARCHAR(50),
    image_url VARCHAR(500) NOT NULL,
    thumbnail_url VARCHAR(500),
    file_type VARCHAR(20) CHECK (file_type IN ('PNG', 'GIF', 'WEBP', 'LOTTIE')),
    keywords TEXT[],
    emoji_match VARCHAR(20),
    order_index INT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_sticker_pack ON sticker(pack_id, order_index);
CREATE INDEX idx_sticker_emoji ON sticker(emoji_match) WHERE emoji_match IS NOT NULL;
```

### 10.3 `user_sticker_pack`
```sql
CREATE TABLE user_sticker_pack (
    user_id UUID NOT NULL,
    pack_id UUID NOT NULL,
    downloaded_at TIMESTAMP DEFAULT NOW(),
    order_index INT,
    PRIMARY KEY (user_id, pack_id)
);

CREATE INDEX idx_user_sticker ON user_sticker_pack(user_id, order_index);
```

### 10.4 `sticker_usage`
```sql
CREATE TABLE sticker_usage (
    user_id UUID NOT NULL,
    sticker_id UUID NOT NULL,
    usage_count INT DEFAULT 1,
    last_used_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (user_id, sticker_id)
);

CREATE INDEX idx_sticker_usage ON sticker_usage(user_id, usage_count DESC);
```

### 10.5 `ai_sticker`
```sql
CREATE TABLE ai_sticker (
    ai_sticker_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    prompt TEXT NOT NULL,
    image_url VARCHAR(500) NOT NULL,
    thumbnail_url VARCHAR(500),
    status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (status IN ('GENERATING', 'ACTIVE', 'FAILED', 'DELETED')),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_ai_sticker_user ON ai_sticker(user_id, created_at DESC);
```

---

## 11. Notification Service Database

### 11.1 `device_token`
```sql
CREATE TABLE device_token (
    device_id VARCHAR(100) PRIMARY KEY,
    user_id UUID NOT NULL,
    platform VARCHAR(20) NOT NULL CHECK (platform IN ('ANDROID', 'IOS', 'WEB', 'PC')),
    push_token VARCHAR(500) NOT NULL,
    voip_token VARCHAR(500),
    app_version VARCHAR(20),
    os_version VARCHAR(20),
    device_model VARCHAR(100),
    device_name VARCHAR(100),
    status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'REVOKED', 'EXPIRED')),
    last_active_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_device_user ON device_token(user_id);
CREATE UNIQUE INDEX idx_device_push_token ON device_token(push_token);
```

### 11.2 `notification`
```sql
CREATE TABLE notification (
    notification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    type VARCHAR(30) NOT NULL CHECK (type IN (
        'MESSAGE', 'FRIEND_REQUEST', 'FRIEND_ACCEPTED', 'GROUP_INVITE', 
        'MENTION', 'REACTION', 'STORY_VIEW', 'STORY_REACTION', 'STORY_REPLY',
        'CALL_MISSED', 'TIMELINE_LIKE', 'TIMELINE_COMMENT', 'TIMELINE_TAG',
        'SYSTEM', 'PROMOTION'
    )),
    title VARCHAR(200) NOT NULL,
    body VARCHAR(500) NOT NULL,
    image_url VARCHAR(500),
    action_type VARCHAR(30) CHECK (action_type IN (
        'OPEN_CHAT', 'OPEN_PROFILE', 'OPEN_GROUP', 'OPEN_STORY', 
        'OPEN_POST', 'OPEN_CALL', 'OPEN_URL', 'NONE'
    )),
    action_data JSONB,
    is_read BOOLEAN DEFAULT FALSE,
    is_pushed BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMP,
    pushed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_notif_user ON notification(user_id, is_read, created_at DESC);
CREATE INDEX idx_notif_unread ON notification(user_id, created_at DESC) WHERE is_read = FALSE;
```

---

## 12. Analytics Service Database

### 12.1 `user_activity_log`
```sql
CREATE TABLE user_activity_log (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    activity_type VARCHAR(50) NOT NULL,
    metadata JSONB,
    device_id VARCHAR(100),
    ip_address VARCHAR(45),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_activity_user ON user_activity_log(user_id, created_at DESC);
CREATE INDEX idx_activity_type ON user_activity_log(activity_type, created_at DESC);
```

### 12.2 `daily_stats`
```sql
CREATE TABLE daily_stats (
    stat_date DATE NOT NULL,
    metric_type VARCHAR(50) NOT NULL,
    value BIGINT NOT NULL,
    metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (stat_date, metric_type)
);
```

### 12.3 `user_stats`
```sql
CREATE TABLE user_stats (
    user_id UUID NOT NULL,
    stat_date DATE NOT NULL,
    messages_sent INT DEFAULT 0,
    messages_received INT DEFAULT 0,
    calls_made INT DEFAULT 0,
    calls_received INT DEFAULT 0,
    call_duration_seconds INT DEFAULT 0,
    stories_posted INT DEFAULT 0,
    posts_created INT DEFAULT 0,
    media_uploaded_bytes BIGINT DEFAULT 0,
    PRIMARY KEY (user_id, stat_date)
);
```

---

## 13. QR & Link Service Database

### 13.1 `qr_code`
```sql
CREATE TABLE qr_code (
    qr_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type VARCHAR(30) NOT NULL CHECK (type IN ('USER_PROFILE', 'GROUP_INVITE', 'ADD_FRIEND')),
    target_id UUID NOT NULL,
    short_code VARCHAR(20) UNIQUE NOT NULL,
    qr_image_url VARCHAR(500),
    scan_count INT DEFAULT 0,
    expires_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_qr_short_code ON qr_code(short_code);
CREATE INDEX idx_qr_target ON qr_code(type, target_id);
```

### 13.2 `short_link`
```sql
CREATE TABLE short_link (
    link_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    short_code VARCHAR(20) UNIQUE NOT NULL,
    full_url TEXT NOT NULL,
    type VARCHAR(30) CHECK (type IN ('GROUP_INVITE', 'SHARE_POST', 'SHARE_STORY', 'PROFILE', 'EXTERNAL')),
    created_by UUID NOT NULL,
    click_count INT DEFAULT 0,
    expires_at TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_short_link_code ON short_link(short_code) WHERE is_active = TRUE;
```

---

## 14. Moderation Service Database

### 14.1 `report`
```sql
CREATE TABLE report (
    report_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL,
    target_type VARCHAR(30) NOT NULL CHECK (target_type IN ('USER', 'MESSAGE', 'CONVERSATION', 'POST', 'STORY', 'COMMENT', 'STICKER')),
    target_id UUID NOT NULL,
    reason_code VARCHAR(30) NOT NULL CHECK (reason_code IN ('SPAM', 'HARASSMENT', 'INAPPROPRIATE', 'SCAM', 'VIOLENCE', 'FAKE_ACCOUNT', 'COPYRIGHT', 'OTHER')),
    reason_text TEXT,
    evidence_media_ids UUID[],
    status VARCHAR(20) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'REVIEWING', 'RESOLVED', 'REJECTED')),
    assigned_to UUID,
    resolution TEXT,
    action_taken VARCHAR(50),
    resolved_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_report_status ON report(status, created_at);
CREATE INDEX idx_report_target ON report(target_type, target_id);
CREATE INDEX idx_report_assigned ON report(assigned_to) WHERE assigned_to IS NOT NULL;
```

### 14.2 `admin_action_log`
```sql
CREATE TABLE admin_action_log (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID NOT NULL,
    action_type VARCHAR(50) NOT NULL CHECK (action_type IN (
        'WARN_USER', 'LOCK_USER', 'UNLOCK_USER', 'DELETE_USER',
        'DELETE_MESSAGE', 'DELETE_POST', 'DELETE_STORY', 'DELETE_COMMENT',
        'BAN_STICKER', 'DISABLE_GROUP', 'RESOLVE_REPORT'
    )),
    target_type VARCHAR(30) NOT NULL,
    target_id UUID NOT NULL,
    reason TEXT,
    metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_admin_log_admin ON admin_action_log(admin_id, created_at DESC);
CREATE INDEX idx_admin_log_target ON admin_action_log(target_type, target_id);
```

### 14.3 `user_warning`
```sql
CREATE TABLE user_warning (
    warning_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    admin_id UUID NOT NULL,
    reason TEXT NOT NULL,
    severity VARCHAR(20) CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH')),
    expires_at TIMESTAMP,
    acknowledged_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_warning_user ON user_warning(user_id, created_at DESC);
```

---

## 15. Event Outbox Pattern

### 15.1 `outbox_event`
```sql
CREATE TABLE outbox_event (
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aggregate_type VARCHAR(50) NOT NULL,
    aggregate_id UUID NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    payload JSONB NOT NULL,
    status VARCHAR(20) DEFAULT 'NEW' CHECK (status IN ('NEW', 'PUBLISHED', 'FAILED')),
    retry_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    published_at TIMESTAMP
);

CREATE INDEX idx_outbox_unpublished ON outbox_event(created_at) WHERE status = 'NEW';
CREATE INDEX idx_outbox_failed ON outbox_event(retry_count) WHERE status = 'FAILED';
```

---

## 16. Backup Service Database ⭐ NEW

### 16.1 `backup_job`
```sql
CREATE TABLE backup_job (
    backup_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    type VARCHAR(20) NOT NULL CHECK (type IN ('FULL', 'CONVERSATION', 'MEDIA_ONLY')),
    conversation_id UUID,  -- NULL for full backup
    status VARCHAR(20) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED', 'EXPIRED')),
    format VARCHAR(20) DEFAULT 'JSON' CHECK (format IN ('JSON', 'ENCRYPTED_JSON')),
    include_media BOOLEAN DEFAULT FALSE,
    file_path VARCHAR(500),  -- Local path or temp storage path
    file_size_bytes BIGINT,
    message_count INT,
    media_count INT,
    encryption_key_hash VARCHAR(255),  -- For encrypted backups
    download_url VARCHAR(500),
    download_expires_at TIMESTAMP,
    error_message TEXT,
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_backup_user ON backup_job(user_id, created_at DESC);
CREATE INDEX idx_backup_status ON backup_job(status);
```

### 16.2 `restore_job`
```sql
CREATE TABLE restore_job (
    restore_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    backup_id UUID,  -- Reference to original backup if known
    source_type VARCHAR(20) NOT NULL CHECK (source_type IN ('UPLOAD', 'BACKUP_JOB')),
    status VARCHAR(20) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'VALIDATING', 'PROCESSING', 'COMPLETED', 'FAILED')),
    file_path VARCHAR(500),
    conversations_restored INT DEFAULT 0,
    messages_restored INT DEFAULT 0,
    media_restored INT DEFAULT 0,
    conflicts_found INT DEFAULT 0,
    conflict_resolution VARCHAR(20) DEFAULT 'SKIP' CHECK (conflict_resolution IN ('SKIP', 'OVERWRITE', 'MERGE')),
    error_message TEXT,
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_restore_user ON restore_job(user_id, created_at DESC);
```

---

## Summary

| Service | Tables | Primary Purpose |
|---------|--------|-----------------|
| Auth | 3 | Account, tokens, OTP |
| User Profile | 3 | Profile, privacy, settings |
| Social Graph | 4 | Friends, blocks, contacts |
| Conversation | 6 | Chats, groups, members, **inbox (CQRS)** |
| Message | 9 | Messages, reactions, polls |
| Media | 2 | File uploads, access control |
| Call | 2 | Voice/video calls |
| Story | 7 | Stories (24h), highlights |
| Timeline | 7 | Posts, comments, likes |
| Sticker | 5 | Sticker packs, AI stickers |
| Notification | 2 | Push notifications |
| Analytics | 3 | Activity logs, stats |
| QR/Link | 2 | QR codes, short links |
| Moderation | 3 | Reports, admin actions |
| Event | 1 | Outbox pattern |
| Backup | 2 | Local backup/restore |

**Total: 61 tables across 16 services**

> **Note**: Using CQRS pattern - `conversation_inbox` is a read model updated by Message Service via Kafka events.
