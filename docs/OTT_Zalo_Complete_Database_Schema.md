# Complete Database Schema - OTT Zalo Clone

> **Version**: 5.0 - Aligned with Class Diagrams  
> **Last Updated**: January 19, 2026  
> **Database**: PostgreSQL (metadata) + Cassandra (messages) + Redis (cache/realtime)  
> **Reference**: Zalo 2024/2025 - 77.8M MAU, 2B messages/day, Kubernetes, AI-first

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         DATABASE ARCHITECTURE                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   PostgreSQL (RDS)             Cassandra (Keyspaces)        Redis (Elc.)    │
│   ────────────────             ─────────────────────        ─────────────   │
│   • Auth (3 tables)            • messages_by_conversation   • Sessions      │
│   • User Profile (3)           • message_idempotency        • Presence      │
│   • Social Graph (4)           • messages_by_user           • Rate Limit    │
│   • Conversation (6)                                        • Seq Gen       │
│   • Message Metadata (6)                                    • Cache         │
│   • Media (5) ← NEW                                                         │
│   • Sticker (5)                                                             │
│   • Moderation (4) ← NEW                                                    │
│   • Story (8)                                                               │
│   • Timeline (7)                                                            │
│   • Notification (2)                                                        │
│   • Analytics (3)                                                           │
│   • QR/Link (2)                                                             │
│   • Event Outbox (1)                                                        │
│   • Backup (2)                                                              │
│                                                                              │
│   Total: 71 tables (PostgreSQL: 68, Cassandra: 3)                           │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 1. Auth Service Database (PostgreSQL)

> ✅ **Status**: Matched with Class Diagram

### 1.1 `auth_account`
```sql
CREATE TABLE auth_account (
    account_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone VARCHAR(20) NOT NULL UNIQUE,
    firebase_uid VARCHAR(128) UNIQUE,
    password_hash VARCHAR(255),
    status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'LOCKED', 'DISABLED', 'DELETED')),
    locked_until TIMESTAMPTZ,
    failed_login_count INT DEFAULT 0,
    last_login_at TIMESTAMPTZ,
    last_login_device_id VARCHAR(100),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
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
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
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
    expires_at TIMESTAMPTZ NOT NULL,
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_otp_target ON auth_otp(target, purpose, created_at DESC);
```

---

## 2. User Profile Service Database (PostgreSQL)

> ✅ **Status**: Matched with Class Diagram

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
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
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
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
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
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 3. Social Graph Service Database (PostgreSQL)

> ✅ **Status**: Matched with Class Diagram

### 3.1 `friend_request`
```sql
CREATE TABLE friend_request (
    request_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_user_id UUID NOT NULL,
    to_user_id UUID NOT NULL,
    message VARCHAR(200),
    source VARCHAR(30) CHECK (source IN ('SEARCH', 'QR', 'CONTACT_SYNC', 'SUGGEST', 'GROUP', 'NEARBY')),
    status VARCHAR(20) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'ACCEPTED', 'DECLINED', 'CANCELED')),
    responded_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
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
    created_at TIMESTAMPTZ DEFAULT NOW(),
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
    created_at TIMESTAMPTZ DEFAULT NOW(),
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
    invited_at TIMESTAMPTZ,
    synced_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_contact UNIQUE (user_id, phone_number)
);

CREATE INDEX idx_contact_user ON contact_sync(user_id);
CREATE INDEX idx_contact_matched ON contact_sync(matched_user_id) WHERE matched_user_id IS NOT NULL;
```

---

## 4. Conversation Service Database (PostgreSQL)

> ✅ **Status**: Matched with Class Diagram

### 4.1 `conversation`
```sql
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
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    joined_by UUID,
    left_at TIMESTAMPTZ,
    removed_by UUID,
    mute_until TIMESTAMPTZ,
    is_pinned BOOLEAN DEFAULT FALSE,
    pin_order INT,
    is_hidden BOOLEAN DEFAULT FALSE,
    last_read_seq BIGINT DEFAULT 0,
    last_read_at TIMESTAMPTZ,
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
    created_at TIMESTAMPTZ DEFAULT NOW(),
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
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
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

CREATE INDEX idx_inbox_user_sort ON conversation_inbox(user_id, is_pinned DESC, last_message_seq DESC);
CREATE INDEX idx_inbox_unread ON conversation_inbox(user_id, unread_count) WHERE unread_count > 0;
```

---

## 5. Message Service Database (Cassandra)

> ✅ **Status**: Matched with Class Diagram (with denormalization for Cassandra)

### 5.1 `messages_by_conversation`
```cql
CREATE TABLE messages_by_conversation (
    conversation_id UUID,
    server_seq BIGINT,
    message_id UUID,
    sender_id UUID,
    client_message_id UUID,
    message_type TEXT,
    content TEXT,
    media_id UUID,
    media_url TEXT,
    media_thumbnail_url TEXT,
    media_mime_type TEXT,
    media_size_bytes BIGINT,
    media_width INT,
    media_height INT,
    media_duration_ms INT,
    sticker_id UUID,
    sticker_url TEXT,
    reply_to_message_id UUID,
    reply_to_seq BIGINT,
    reply_to_sender_id UUID,
    reply_to_content TEXT,
    reply_to_type TEXT,
    forward_from_message_id UUID,
    forward_from_conversation_id UUID,
    forward_from_sender_id UUID,
    mentions SET<UUID>,
    status TEXT,
    is_edited BOOLEAN,
    edited_at TIMESTAMP,
    server_ts TIMESTAMP,
    expires_at TIMESTAMP,
    PRIMARY KEY ((conversation_id), server_seq)
) WITH CLUSTERING ORDER BY (server_seq DESC)
  AND default_time_to_live = 31536000
  AND gc_grace_seconds = 86400;
```

### 5.2 `message_idempotency_by_sender`
```cql
CREATE TABLE message_idempotency_by_sender (
    sender_id UUID,
    client_message_id UUID,
    conversation_id UUID,
    server_seq BIGINT,
    message_id UUID,
    created_at TIMESTAMP,
    PRIMARY KEY ((sender_id), client_message_id)
) WITH default_time_to_live = 604800;
```

### 5.3 `messages_by_user`
```cql
CREATE TABLE messages_by_user (
    user_id UUID,
    year_month INT,
    server_ts TIMESTAMP,
    conversation_id UUID,
    message_id UUID,
    server_seq BIGINT,
    message_type TEXT,
    content TEXT,
    PRIMARY KEY ((user_id, year_month), server_ts, message_id)
) WITH CLUSTERING ORDER BY (server_ts DESC, message_id DESC)
  AND default_time_to_live = 31536000;
```

---

## 6. Message Metadata Service Database (PostgreSQL)

> ✅ **Status**: Matched with Class Diagram

### 6.1 `message_reaction`
```sql
CREATE TABLE message_reaction (
    reaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL,
    message_id UUID NOT NULL,
    server_seq BIGINT NOT NULL,
    user_id UUID NOT NULL,
    emoji VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_reaction UNIQUE (message_id, user_id)
);

CREATE INDEX idx_reaction_msg ON message_reaction(message_id);
CREATE INDEX idx_reaction_conv ON message_reaction(conversation_id, server_seq DESC);
```

### 6.2 `message_receipt`
```sql
CREATE TABLE message_receipt (
    conversation_id UUID NOT NULL,
    message_id UUID NOT NULL,
    server_seq BIGINT NOT NULL,
    user_id UUID NOT NULL,
    delivered_at TIMESTAMPTZ,
    seen_at TIMESTAMPTZ,
    PRIMARY KEY (conversation_id, message_id, user_id)
);

CREATE INDEX idx_receipt_user ON message_receipt(user_id, seen_at DESC);
CREATE INDEX idx_receipt_conv_seq ON message_receipt(conversation_id, server_seq);
```

### 6.3 `pinned_message`
```sql
CREATE TABLE pinned_message (
    pin_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL,
    message_id UUID NOT NULL,
    server_seq BIGINT NOT NULL,
    pinned_by UUID NOT NULL,
    pinned_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_pinned_msg UNIQUE (conversation_id, message_id)
);

CREATE INDEX idx_pinned_conv ON pinned_message(conversation_id, pinned_at DESC);
```

### 6.4-6.6 `poll`, `poll_option`, `poll_vote`
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
    expires_at TIMESTAMPTZ,
    status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'CLOSED')),
    created_at TIMESTAMPTZ DEFAULT NOW()
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
    voted_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (poll_id, option_id, user_id)
);

CREATE INDEX idx_poll_conv ON poll(conversation_id);
CREATE INDEX idx_poll_option ON poll_option(poll_id, option_order);
```

---

## 7. Media Service Database (PostgreSQL) ⭐ UPDATED

> ⚠️ **Status**: FIXED - Added missing tables from Class Diagram

### 7.1 `media_metadata` (Renamed from media_object)
```sql
-- Core media metadata table - stores S3 reference
CREATE TABLE media_metadata (
    media_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL,
    media_type VARCHAR(20) NOT NULL CHECK (media_type IN ('IMAGE', 'VIDEO', 'DOCUMENT', 'AUDIO')),
    mime_type VARCHAR(100) NOT NULL,
    original_filename VARCHAR(255),
    -- S3 Storage
    bucket VARCHAR(50) NOT NULL,
    object_key VARCHAR(500) NOT NULL,
    region VARCHAR(20) DEFAULT 'ap-southeast-1',
    -- CDN URLs (derived after processing)
    cloudfront_url VARCHAR(500),
    preview_url VARCHAR(500),
    -- Metadata
    size_bytes BIGINT NOT NULL,
    checksum_sha256 VARCHAR(64),
    width INT,
    height INT,
    duration_ms INT,
    needs_processing BOOLEAN DEFAULT TRUE,
    -- Lifecycle
    status VARCHAR(20) DEFAULT 'PENDING_UPLOAD' CHECK (status IN (
        'PENDING_UPLOAD', 'UPLOADED', 'PROCESSING', 'READY', 'FAILED', 'DELETED'
    )),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_media_owner ON media_metadata(owner_user_id, created_at DESC);
CREATE INDEX idx_media_status ON media_metadata(status);
CREATE INDEX idx_media_type ON media_metadata(media_type, created_at DESC);
```

### 7.2 `upload_request` ⭐ NEW
```sql
-- Presigned URL upload tracking
CREATE TABLE upload_request (
    upload_request_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    expected_size_bytes BIGINT NOT NULL,
    -- Presigned URL info
    presigned_url TEXT NOT NULL,
    object_key VARCHAR(500) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    -- Context
    source_type VARCHAR(30) CHECK (source_type IN ('CHAT', 'STORY', 'TIMELINE', 'AVATAR', 'STICKER')),
    source_id UUID,
    -- Status
    status VARCHAR(20) DEFAULT 'ISSUED' CHECK (status IN ('ISSUED', 'CONFIRMED', 'EXPIRED', 'CANCELLED')),
    confirmed_media_id UUID,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_upload_user ON upload_request(owner_user_id, created_at DESC);
CREATE INDEX idx_upload_status ON upload_request(status, expires_at);
```

### 7.3 `media_job` ⭐ NEW
```sql
-- Background processing jobs (thumbnail, compress, transcode)
CREATE TABLE media_job (
    media_job_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    media_id UUID NOT NULL,
    job_type VARCHAR(20) NOT NULL CHECK (job_type IN ('THUMBNAIL', 'COMPRESS', 'TRANSCODE')),
    status VARCHAR(20) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'RUNNING', 'DONE', 'FAILED')),
    kafka_topic VARCHAR(100),
    payload_json JSONB,
    result_json JSONB,
    retry_count INT DEFAULT 0,
    next_run_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_media_job_media ON media_job(media_id);
CREATE INDEX idx_media_job_status ON media_job(status, next_run_at);
```

### 7.4 `media_variant` ⭐ NEW
```sql
-- Different versions of media (thumbnail, compressed, different resolutions)
CREATE TABLE media_variant (
    media_variant_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    media_id UUID NOT NULL,
    variant_type VARCHAR(20) NOT NULL CHECK (variant_type IN ('THUMBNAIL', 'COMPRESSED', 'PREVIEW', 'HD', 'SD')),
    object_key VARCHAR(500) NOT NULL,
    width INT,
    height INT,
    size_bytes BIGINT,
    status VARCHAR(20) DEFAULT 'READY' CHECK (status IN ('PROCESSING', 'READY', 'FAILED')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_media_variant ON media_variant(media_id, variant_type);
```

### 7.5 `user_media_library_item` ⭐ NEW
```sql
-- User's saved media (from chat, stories, etc.)
CREATE TABLE user_media_library_item (
    user_media_lib_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    media_id UUID NOT NULL,
    saved_at TIMESTAMPTZ DEFAULT NOW(),
    source_type VARCHAR(30) CHECK (source_type IN ('CHAT', 'STORY', 'TIMELINE', 'UPLOAD')),
    source_id UUID,
    CONSTRAINT unique_user_media UNIQUE (user_id, media_id)
);

CREATE INDEX idx_user_media_lib ON user_media_library_item(user_id, saved_at DESC);
```

---

## 8. Sticker Service Database (PostgreSQL) ⭐ UPDATED

> ⚠️ **Status**: FIXED - Aligned with Class Diagram (using mediaId pattern)

### 8.1 `sticker_pack`
```sql
CREATE TABLE sticker_pack (
    sticker_pack_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID,  -- NULL for official packs
    name VARCHAR(100) NOT NULL,
    description VARCHAR(500),
    cover_media_id UUID NOT NULL,  -- ← Reference to media_metadata
    -- Status
    status VARCHAR(20) DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'PUBLISHED', 'SUSPENDED')),
    -- Stats
    sticker_count INT DEFAULT 0,
    download_count INT DEFAULT 0,
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_sticker_pack_owner ON sticker_pack(owner_user_id) WHERE owner_user_id IS NOT NULL;
CREATE INDEX idx_sticker_pack_status ON sticker_pack(status);
CREATE INDEX idx_sticker_pack_popular ON sticker_pack(download_count DESC) WHERE status = 'PUBLISHED';
```

### 8.2 `sticker`
```sql
CREATE TABLE sticker (
    sticker_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pack_id UUID NOT NULL,
    name VARCHAR(50),
    media_id UUID NOT NULL,  -- ← Reference to media_metadata
    is_animated BOOLEAN DEFAULT FALSE,
    display_order INT NOT NULL,
    status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'HIDDEN', 'BLOCKED')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_sticker_pack ON sticker(pack_id, display_order);
CREATE INDEX idx_sticker_status ON sticker(status);
```

### 8.3 `user_sticker_pack`
```sql
CREATE TABLE user_sticker_pack (
    user_id UUID NOT NULL,
    pack_id UUID NOT NULL,
    installed_at TIMESTAMPTZ DEFAULT NOW(),
    pinned_order INT,  -- NULL if not pinned
    PRIMARY KEY (user_id, pack_id)
);

CREATE INDEX idx_user_sticker_pack ON user_sticker_pack(user_id, pinned_order NULLS LAST);
```

### 8.4 `sticker_usage`
```sql
CREATE TABLE sticker_usage (
    user_id UUID NOT NULL,
    sticker_id UUID NOT NULL,
    usage_count INT DEFAULT 1,
    last_used_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, sticker_id)
);

CREATE INDEX idx_sticker_usage ON sticker_usage(user_id, usage_count DESC);
```

### 8.5 `ai_sticker`
```sql
CREATE TABLE ai_sticker (
    ai_sticker_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    prompt TEXT NOT NULL,
    media_id UUID NOT NULL,  -- ← Reference to media_metadata
    status VARCHAR(20) DEFAULT 'GENERATING' CHECK (status IN ('GENERATING', 'ACTIVE', 'FAILED', 'DELETED')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_ai_sticker_user ON ai_sticker(user_id, created_at DESC);
```

---

## 9. Moderation Service Database (PostgreSQL) ⭐ UPDATED

> ⚠️ **Status**: FIXED - Complete rewrite based on Class Diagram

### 9.1 `content_report`
```sql
CREATE TABLE content_report (
    content_report_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_user_id UUID NOT NULL,
    target_type VARCHAR(20) NOT NULL CHECK (target_type IN ('MEDIA', 'STICKER', 'TIMELINE', 'MESSAGE')),
    target_id UUID NOT NULL,
    reason_code VARCHAR(30) NOT NULL CHECK (reason_code IN (
        'SPAM', 'HARASSMENT', 'INAPPROPRIATE', 'VIOLENCE', 'SCAM', 'COPYRIGHT', 'OTHER'
    )),
    description TEXT,
    status VARCHAR(20) DEFAULT 'NEW' CHECK (status IN ('NEW', 'IN_REVIEW', 'RESOLVED')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_report_status ON content_report(status, created_at);
CREATE INDEX idx_report_target ON content_report(target_type, target_id);
CREATE INDEX idx_report_reporter ON content_report(reporter_user_id);
```

### 9.2 `moderation_decision` ⭐ NEW
```sql
CREATE TABLE moderation_decision (
    mod_dec_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id UUID NOT NULL,
    decided_by UUID NOT NULL,  -- Admin user ID
    decision_type VARCHAR(20) NOT NULL CHECK (decision_type IN ('NO_ACTION', 'REMOVE', 'BLOCK', 'SUSPEND')),
    notes TEXT,
    decided_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_mod_dec_report ON moderation_decision(report_id);
CREATE INDEX idx_mod_dec_admin ON moderation_decision(decided_by, decided_at DESC);
```

### 9.3 `moderation_action` ⭐ NEW
```sql
-- Actions to be executed by target services (via Kafka)
CREATE TABLE moderation_action (
    mod_act_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    decision_id UUID NOT NULL,
    target_service VARCHAR(50) NOT NULL,  -- e.g., 'media-service', 'sticker-service'
    action_type VARCHAR(50) NOT NULL,     -- e.g., 'DELETE_MEDIA', 'HIDE_STICKER'
    payload_json JSONB NOT NULL,
    status VARCHAR(20) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'SENT', 'ACKED', 'FAILED')),
    retry_count INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_mod_action_decision ON moderation_action(decision_id);
CREATE INDEX idx_mod_action_status ON moderation_action(status, created_at);
```

### 9.4 `admin_action_log`
```sql
-- Audit log for all admin actions
CREATE TABLE admin_action_log (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID NOT NULL,
    action_type VARCHAR(50) NOT NULL,
    target_type VARCHAR(30) NOT NULL,
    target_id UUID NOT NULL,
    reason TEXT,
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_admin_log_admin ON admin_action_log(admin_id, created_at DESC);
CREATE INDEX idx_admin_log_target ON admin_action_log(target_type, target_id);
```

---

## 10-17. Other Services (Unchanged)

> Story, Timeline, Notification, Analytics, QR/Link, Call, Event Outbox, Backup services remain the same as version 4.0

*(Sections 10-17 remain unchanged from previous version for brevity - refer to version 4.0)*

---

## Redis Data Structures

```
# Sessions & Presence
presence:user:{userId}           → HASH {online, lastSeen, deviceId}
socket:conn:{connectionId}       → HASH {userId, deviceId}
socket:user:{userId}             → SET of connectionIds

# Rate Limiting
rl:msg:{userId}:{minute}         → INT (TTL 60s)
rl:ai:{userId}:{minute}          → INT (TTL 60s)
rl:upload:{userId}:{hour}        → INT (TTL 3600s)

# Sequence Generation
seq:conv:{conversationId}        → BIGINT (atomic INCR)

# Idempotency Cache
dedup:msg:{senderId}:{clientMsgId} → HASH {messageId, serverSeq} (TTL 7d)

# Upload Tracking
upload:pending:{uploadRequestId}   → JSON {status, mediaId} (TTL 15m)

# Caching
cache:conv:settings:{convId}:{userId} → JSON (TTL 5m)
cache:user:profile:{userId}           → JSON (TTL 5m)
cache:sticker:pack:{packId}           → JSON (TTL 1h)
```

---

## AWS Infrastructure Integration

### S3 Buckets
| Bucket | Purpose | Lifecycle |
|--------|---------|-----------|
| `ott-media-prod` | Chat media, stories, timeline | Glacier after 1 year |
| `ott-avatars-prod` | User/group avatars | Keep 3 versions |
| `ott-stickers-prod` | Sticker packs | Permanent |
| `ott-backups-prod` | User backups (encrypted) | Delete after 30 days |
| `ott-temp-prod` | Processing temp files | Delete after 24 hours |

### CloudFront Distribution
- Domain: `cdn.ott-zalo.example.com`
- Origins: All S3 buckets above
- TTL: 1 day for media, 1 year for stickers
- Signed URLs for private media

---

## Summary

### Changes from Version 4.0 → 5.0

| Service | Change | Impact |
|---------|--------|--------|
| **Media** | Added `upload_request`, `media_job`, `media_variant`, `user_media_library_item` | Presigned URL flow, background processing |
| **Media** | Renamed `media_object` → `media_metadata` | Clarity |
| **Sticker** | Changed from URL-based to `media_id` reference | Integrated with Media Service |
| **Sticker** | Fixed field names (`installed_at`, `pinned_order`) | Aligned with class diagram |
| **Moderation** | Added `moderation_decision`, `moderation_action` | Complete workflow support |
| **Moderation** | Renamed `report` → `content_report` | Aligned with class diagram |

### Table Count

| Category | Tables | Notes |
|----------|--------|-------|
| Auth | 3 | Unchanged |
| User | 3 | Unchanged |
| Social | 4 | Unchanged |
| Conversation | 6 | Unchanged |
| Message (Cassandra) | 3 | Unchanged |
| Message Metadata | 6 | Unchanged |
| **Media** | **5** | +3 new tables |
| **Sticker** | **5** | Field changes |
| **Moderation** | **4** | +2 new tables |
| Story | 8 | Unchanged |
| Timeline | 7 | Unchanged |
| Notification | 2 | Unchanged |
| Analytics | 3 | Unchanged |
| QR/Link | 2 | Unchanged |
| Call | 2 | Unchanged |
| Event Outbox | 1 | Unchanged |
| Backup | 2 | Unchanged |
| **Total** | **71** | +5 from v4.0 |

---

> **Zalo Reference (2024/2025)**:  
> - 77.8M MAU, 2B messages/day  
> - Kubernetes + KubeSphere for orchestration  
> - Redis for caching, Kafka for event streaming  
> - AI integration: 20% users engage with AI features monthly  
> - Own LLM + Kiki chatbot launched January 2025
