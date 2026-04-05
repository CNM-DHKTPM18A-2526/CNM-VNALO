do $$
begin
    if not exists (
        select 1
        from pg_constraint
        where conname = 'uq_story_view_story_viewer'
    ) then
        alter table content.story_view
            add constraint uq_story_view_story_viewer unique (story_id, viewer_id);
    end if;
end $$;