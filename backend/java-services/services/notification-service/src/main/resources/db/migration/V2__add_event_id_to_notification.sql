ALTER TABLE notification.notification
ADD COLUMN IF NOT EXISTS event_id UUID;

CREATE UNIQUE INDEX IF NOT EXISTS uk_notification_event_id
ON notification.notification (event_id);