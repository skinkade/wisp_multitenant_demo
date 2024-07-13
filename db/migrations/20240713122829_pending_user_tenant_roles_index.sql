-- migrate:up

CREATE INDEX IX_pending_user_tenant_role_tenant
ON pending_user_tenant_roles (tenant_id);

CREATE UNIQUE INDEX UX_pending_user_tenant_role_email_tenant
ON pending_user_tenant_roles (email_address, tenant_id);

-- migrate:down

DROP INDEX IX_pending_user_tenant_role_tenant;
DROP INDEX UX_pending_user_tenant_role_email_tenant;
