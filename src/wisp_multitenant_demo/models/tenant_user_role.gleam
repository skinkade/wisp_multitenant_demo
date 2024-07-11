import gleam/dynamic.{type Dynamic}
import gleam/pgo.{type Connection, type QueryError}
import gleam/result
import wisp_multitenant_demo/models/tenant.{type TenantId}
import wisp_multitenant_demo/models/user.{type UserId}

pub type TenantUserRole {
  TenantOwner
  TenantAdmin
  TenantMember
}

pub fn role_to_string(role: TenantUserRole) -> String {
  case role {
    TenantMember -> "member"
    TenantAdmin -> "admin"
    TenantOwner -> "owner"
  }
}

pub fn role_from_string(str: String) -> Result(TenantUserRole, Nil) {
  case str {
    "member" -> Ok(TenantMember)
    "admin" -> Ok(TenantAdmin)
    "owner" -> Ok(TenantOwner)
    _ -> Error(Nil)
  }
}

pub fn decode_role(d: Dynamic) {
  use value <- result.try(dynamic.string(d))
  // TODO: parsing / error handling
  let assert Ok(role) = role_from_string(value)
  Ok(role)
}

pub fn set_tenant_user_role(
  db: Connection,
  tenant_id: TenantId,
  user_id: UserId,
  role: TenantUserRole,
) -> Result(Nil, QueryError) {
  let sql =
    "
        INSERT INTO tenant_user_roles
        (tenant_id, user_id, role)
        VALUES
        ($1, $2, $3)
        ON CONFLICT (tenant_id, user_id)
        DO UPDATE SET role = $3;
    "

  use _ <- result.try({
    pgo.execute(
      sql,
      db,
      [
        tenant_id |> tenant.id_to_int() |> pgo.int(),
        user_id |> user.id_to_int() |> pgo.int(),
        role |> role_to_string() |> pgo.text(),
      ],
      dynamic.dynamic,
    )
  })

  Ok(Nil)
}

pub fn remove_tenant_user_role(
  db: Connection,
  tenant_id: TenantId,
  user_id: UserId,
) -> Result(Nil, QueryError) {
  let sql =
    "
        DELETE FROM tenant_user_roles
        WHERE tenant_id = $1
            AND user_id = $2;
    "

  use _ <- result.try({
    pgo.execute(
      sql,
      db,
      [
        tenant_id |> tenant.id_to_int() |> pgo.int(),
        user_id |> user.id_to_int() |> pgo.int(),
      ],
      dynamic.dynamic,
    )
  })

  Ok(Nil)
}

pub type UserTenantRole {
  UserTenantRole(
    tenant_id: TenantId,
    tenant_full_name: String,
    role: TenantUserRole,
  )
}

pub fn decode_assigned_role(d: Dynamic) {
  let decoder =
    dynamic.decode3(
      UserTenantRole,
      dynamic.element(0, tenant.decode_tenant_id),
      dynamic.element(1, dynamic.string),
      dynamic.element(2, decode_role),
    )

  decoder(d)
}

pub fn get_user_tenant_roles(
  db: Connection,
  user_id: UserId,
) -> Result(List(UserTenantRole), QueryError) {
  let sql =
    "
      SELECT
        tur.tenant_id,
        t.full_name,
        tur.role
      FROM tenant_user_roles tur
      JOIN tenants t
        ON tur.tenant_id = t.id
      WHERE user_id = $1;
    "

  use result <- result.try({
    pgo.execute(
      sql,
      db,
      [user_id |> user.id_to_int() |> pgo.int()],
      decode_assigned_role,
    )
  })

  Ok(result.rows)
}
