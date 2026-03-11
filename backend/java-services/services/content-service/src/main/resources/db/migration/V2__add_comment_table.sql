create table if not exists content.comment (
    comment_id uuid primary key,
    post_id uuid not null,
    author_id uuid not null,
    parent_comment_id uuid null,
    content_text text not null,
    like_count integer not null default 0,
    status varchar(20) not null default 'ACTIVE',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    constraint chk_comment_status
        check (status in ('ACTIVE', 'DELETED')),

    constraint fk_comment_post
        foreign key (post_id)
        references content.post(post_id)
        on delete cascade,

    constraint fk_comment_parent
        foreign key (parent_comment_id)
        references content.comment(comment_id)
        on delete cascade
);

create index if not exists idx_comment_post_id
    on content.comment(post_id);

create index if not exists idx_comment_author_id
    on content.comment(author_id);

create index if not exists idx_comment_parent_comment_id
    on content.comment(parent_comment_id);

create index if not exists idx_comment_created_at
    on content.comment(created_at desc);