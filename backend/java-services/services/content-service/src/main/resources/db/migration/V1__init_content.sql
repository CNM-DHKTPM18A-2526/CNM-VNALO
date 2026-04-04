-- =====================================================
-- VNALO Content Service
-- Schema: content
-- Tables: post, comment
-- =====================================================

create schema if not exists content;

-- =====================================================
-- POST TABLE
-- =====================================================

create table if not exists content.post (
    post_id uuid primary key,
    author_id uuid not null,

    content_text text,

    media_urls jsonb not null default '[]'::jsonb,

    visibility varchar(20) not null default 'PUBLIC',

    like_count integer not null default 0,
    comment_count integer not null default 0,
    share_count integer not null default 0,

    status varchar(20) not null default 'ACTIVE',

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    constraint chk_post_visibility
        check (visibility in ('PUBLIC','FRIENDS','PRIVATE')),

    constraint chk_post_status
        check (status in ('ACTIVE','DELETED'))
);

create index idx_post_author_id
    on content.post(author_id);

create index idx_post_created_at
    on content.post(created_at desc);

-- =====================================================
-- COMMENT TABLE
-- =====================================================

create table if not exists content.comment (
    comment_id uuid primary key,

    post_id uuid not null,
    author_id uuid not null,

    parent_comment_id uuid,

    content_text text not null,

    like_count integer not null default 0,

    status varchar(20) not null default 'ACTIVE',

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    constraint chk_comment_status
        check (status in ('ACTIVE','DELETED')),

    constraint fk_comment_post
        foreign key (post_id)
        references content.post(post_id)
        on delete cascade,

    constraint fk_comment_parent
        foreign key (parent_comment_id)
        references content.comment(comment_id)
        on delete cascade
);

create index idx_comment_post_id
    on content.comment(post_id);

create index idx_comment_author_id
    on content.comment(author_id);

create index idx_comment_created_at
    on content.comment(created_at desc);