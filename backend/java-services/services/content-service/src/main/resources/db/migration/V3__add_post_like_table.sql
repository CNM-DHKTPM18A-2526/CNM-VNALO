create table if not exists content.post_like (
    post_like_id uuid primary key,
    post_id uuid not null,
    user_id uuid not null,
    created_at timestamptz not null default now(),

    constraint fk_post_like_post
        foreign key (post_id)
        references content.post(post_id)
        on delete cascade,

    constraint uq_post_like unique (post_id, user_id)
);

create index if not exists idx_post_like_post_id
    on content.post_like(post_id);

create index if not exists idx_post_like_user_id
    on content.post_like(user_id);