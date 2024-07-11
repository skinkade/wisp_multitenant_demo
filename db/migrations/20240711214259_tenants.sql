-- migrate:up

CREATE TABLE tenants (
    id INT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    full_name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
)

-- migrate:down

DROP TABLE tenants;
