CREATE EXTENSION IF NOT EXISTS vector;
CREATE TABLE journal_events (event_id text PRIMARY KEY, incident_id text NOT NULL, occurred_at timestamptz NOT NULL, logical_clock bigint NOT NULL, event_type text NOT NULL, payload jsonb NOT NULL, search tsvector GENERATED ALWAYS AS (to_tsvector('simple', payload::text)) STORED);
CREATE INDEX journal_events_search_idx ON journal_events USING gin (search);
CREATE TABLE approvals (id text PRIMARY KEY, incident_id text NOT NULL, action_digest char(64) NOT NULL, approver_slack_user_id text NOT NULL, issued_at timestamptz NOT NULL, expires_at timestamptz NOT NULL, role text NOT NULL);
CREATE TABLE action_reservations (incident_id text NOT NULL, action_digest char(64) NOT NULL, status text NOT NULL, operation_id text, PRIMARY KEY (incident_id, action_digest));
CREATE TABLE action_receipts (operation_id text PRIMARY KEY, incident_id text NOT NULL, action_digest char(64) NOT NULL, recorded_at timestamptz NOT NULL, receipt jsonb NOT NULL, UNIQUE (incident_id, action_digest));
