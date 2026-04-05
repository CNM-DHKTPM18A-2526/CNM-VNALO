CREATE TABLE IF NOT EXISTS notification_device (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  device_id VARCHAR(100) NOT NULL,
  platform VARCHAR(20) NOT NULL,
  fcm_token TEXT NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT uq_notification_device UNIQUE (user_id, device_id)
);

CREATE TABLE IF NOT EXISTS notification (
  notification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  type VARCHAR(50) NOT NULL,
  title VARCHAR(200),
  body VARCHAR(500),
  data JSONB,
  is_read BOOLEAN DEFAULT FALSE,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notification_user_created
ON notification.notification (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_device_user_active
ON notification.notification_device (user_id, is_active);

