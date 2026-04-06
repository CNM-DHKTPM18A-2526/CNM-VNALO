CREATE TABLE IF NOT EXISTS analytics_event (
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type VARCHAR(50) NOT NULL,
    actor_user_id UUID,
    target_type VARCHAR(30),
    target_id UUID,
    source_service VARCHAR(50) NOT NULL,
    occurred_at TIMESTAMPTZ NOT NULL,
    payload_json JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_analytics_event_type_time
    ON analytics_event(event_type, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_analytics_event_source_time
    ON analytics_event(source_service, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_analytics_event_actor
    ON analytics_event(actor_user_id, occurred_at DESC);

CREATE TABLE IF NOT EXISTS analytics_daily_metric (
    metric_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    metric_date DATE NOT NULL,
    metric_key VARCHAR(50) NOT NULL,
    dimension_key VARCHAR(50),
    dimension_value VARCHAR(100),
    metric_value BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_daily_metric UNIQUE (metric_date, metric_key, dimension_key, dimension_value)
);

CREATE INDEX IF NOT EXISTS idx_analytics_metric_date
    ON analytics_daily_metric(metric_date DESC, metric_key);

CREATE TABLE IF NOT EXISTS analytics_backfill_job (
    job_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_date DATE NOT NULL,
    to_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL,
    total_days INT NOT NULL,
    processed_days INT NOT NULL DEFAULT 0,
    error_message VARCHAR(500),
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    finished_at TIMESTAMPTZ,
    CONSTRAINT uq_backfill_job_range UNIQUE (from_date, to_date)
);

CREATE INDEX IF NOT EXISTS idx_backfill_job_status_started
    ON analytics_backfill_job(status, started_at DESC);