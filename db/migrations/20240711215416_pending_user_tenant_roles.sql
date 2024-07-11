-- migrate:up

CREATE TABLE pending_user_tenant_roles (
    id INT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    email_address citext NOT NULL,
    tenant_id INT NOT NULL
        REFERENCES tenants (id),
    role_desc TEXT NOT NULL
);

-- migrate:down

DROP TABLE pending_user_tenant_roles;
