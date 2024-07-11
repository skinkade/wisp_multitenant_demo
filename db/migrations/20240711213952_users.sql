-- migrate:up

CREATE EXTENSION IF NOT EXISTS citext;

CREATE TABLE users (
    id INT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    email_address citext NOT NULL,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX UX_user_email
ON users (email_address);

-- migrate:down

DROP TABLE users;
