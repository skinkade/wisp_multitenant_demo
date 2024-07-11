-- migrate:up

CREATE TABLE user_tenant_roles(
    user_id INT NOT NULL
        REFERENCES users (id),
    tenant_id INT NOT NULL
        REFERENCES tenants (id),
    PRIMARY KEY (user_id, tenant_id),
    role_desc TEXT NOT NULL
)

-- migrate:down

DROP TABLE user_tenant_roles;
