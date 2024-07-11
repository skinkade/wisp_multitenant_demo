import birl.{type Time}
import birl/duration
import gleam/bit_array
import gleam/bool
import gleam/crypto
import gleam/dynamic.{type Dynamic}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/pgo.{type Connection}
import gleam/result
import wisp
import wisp_multitenant_demo/models/tenant
import wisp_multitenant_demo/models/user
import wisp_multitenant_demo/models/user_tenant_role.{type UserTenantRole}
import wisp_multitenant_demo/types/email.{type Email}
import wisp_multitenant_demo/types/password.{type Password}
import wisp_multitenant_demo/types/time

pub type PendingUserTenantRole {
  PendingUserTenantRole(
    email_address: Email,
    tenant_id: tenant.TenantId,
    role: user_tenant_role.UserTenantRole,
  )
}

pub fn decode_pending_user_sql(d: Dynamic) {
  let decoder =
    dynamic.decode3(
      PendingUserTenantRole,
      dynamic.element(0, email.decode_email),
      dynamic.element(1, tenant.decode_tenant_id),
      dynamic.element(2, user_tenant_role.decode_role),
    )

  decoder(d)
}

pub type PendingUserToken {
  PendingUserToken(value: String)
}

pub fn create_pending_user_tenant_role(
  db: Connection,
  email: Email,
  tenant_id: tenant.TenantId,
  role: UserTenantRole,
) -> Result(Nil, pgo.QueryError) {
  let sql =
    "
        INSERT INTO pending_user_tenant_roles
        (email_address, tenant_id, role_desc)
        VALUES
        ($1, $2, $3)
        ON CONFLICT (email_address, tenant_id)
        DO UPDATE SET role_desc = $3;
    "

  use _ <- result.try({
    pgo.execute(
      sql,
      db,
      [
        email |> email.to_string() |> pgo.text(),
        tenant_id |> tenant.id_to_int() |> pgo.int(),
        role |> user_tenant_role.role_to_string() |> pgo.text(),
      ],
      dynamic.dynamic,
    )
  })

  Ok(Nil)
}

pub fn delete_pending_roles_by_email_and_tenant(
  db: Connection,
  email: Email,
  tenant_id: tenant.TenantId,
) -> Result(Nil, pgo.QueryError) {
  let sql =
    "
        DELETE FROM pending_user_tenant_roles
        WHERE email_address = $1
            AND tenant_id = $2;
    "

  use _ <- result.try({
    pgo.execute(
      sql,
      db,
      [
        email |> email.to_string() |> pgo.text(),
        tenant_id |> tenant.id_to_int() |> pgo.int(),
      ],
      dynamic.dynamic,
    )
  })

  Ok(Nil)
}

pub fn delete_pending_roles_by_email(
  db: Connection,
  email: Email,
) -> Result(Nil, pgo.QueryError) {
  let sql =
    "
        DELETE FROM pending_user_tenant_roles
        WHERE email_address = $1;
    "

  use _ <- result.try({
    pgo.execute(
      sql,
      db,
      [email |> email.to_string() |> pgo.text()],
      dynamic.dynamic,
    )
  })

  Ok(Nil)
}

pub type PendingTenantRole {
  PendingTenantRole(tenant_id: tenant.TenantId, role: UserTenantRole)
}

pub fn decode_pending_tenant_role(d: Dynamic) {
  let decoder =
    dynamic.decode2(
      PendingTenantRole,
      dynamic.element(0, tenant.decode_tenant_id),
      dynamic.element(1, user_tenant_role.decode_role),
    )

  decoder(d)
}

pub fn get_pending_roles_by_email(
  db: Connection,
  email: Email,
) -> Result(List(PendingTenantRole), pgo.QueryError) {
  let sql =
    "
        SELECT tenant_id, role_desc
        FROM pending_user_tenant_roles
        WHERE email_address = $1;
    "

  use result <- result.try({
    pgo.execute(
      sql,
      db,
      [email |> email.to_string() |> pgo.text()],
      decode_pending_tenant_role,
    )
  })

  Ok(result.rows)
}
