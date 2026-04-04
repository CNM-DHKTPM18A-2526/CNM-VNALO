CREATE SCHEMA IF NOT EXISTS notification;

-- move table nếu đang ở public
ALTER TABLE IF EXISTS public.notification_device SET SCHEMA notification;
ALTER TABLE IF EXISTS public.notification SET SCHEMA notification;