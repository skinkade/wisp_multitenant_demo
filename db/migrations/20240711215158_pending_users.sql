-- migrate:up

CREATE TABLE pending_users (
    id INT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    email_address citext NOT NULL,
    invite_token_hash BYTEA NOT NULL,
    invited_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL
);

CREATE UNIQUE INDEX UX_pending_user_token_hash
ON pending_users (invite_token_hash);

CREATE UNIQUE INDEX UX_pending_user_email
ON pending_users (email_address);

-- migrate:down

DROP TABLE pending_users;
