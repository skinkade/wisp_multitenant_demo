import gleam/dynamic.{type Dynamic}
import gleam/pgo.{type Connection, type QueryError}
import gleam/result
import wisp_multitenant_demo/models/tenant.{type TenantId}
import wisp_multitenant_demo/models/user.{type UserId}

pub type UserTenantRole {
  TenantOwner
  TenantAdmin
  TenantMember
}

pub fn role_to_string(role: UserTenantRole) -> String {
  case role {
    TenantMember -> "member"
    TenantAdmin -> "admin"
    TenantOwner -> "owner"
  }
}

pub fn role_from_string(str: String) -> Result(UserTenantRole, Nil) {
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

pub fn set_user_tenant_role(
  db: Connection,
  user_id: UserId,
  tenant_id: TenantId,
  role: UserTenantRole,
) -> Result(Nil, QueryError) {
  let sql =
    "
        INSERT INTO user_tenant_roles
        (user_id, tenant_id, role_desc)
        VALUES
        ($1, $2, $3)
        ON CONFLICT (user_id, tenant_id)
        DO UPDATE SET role_desc = $3;
    "

  use _ <- result.try({
    pgo.execute(
      sql,
      db,
      [
        user_id |> user.id_to_int() |> pgo.int(),
        tenant_id |> tenant.id_to_int() |> pgo.int(),
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
        WHERE user_id = $1
          AND tenant_id = $2;
    "

  use _ <- result.try({
    pgo.execute(
      sql,
      db,
      [
        user_id |> user.id_to_int() |> pgo.int(),
        tenant_id |> tenant.id_to_int() |> pgo.int(),
      ],
      dynamic.dynamic,
    )
  })

  Ok(Nil)
}

pub type UserTenantRoleForAccess {
  UserTenantRoleForAccess(
    tenant_id: TenantId,
    tenant_full_name: String,
    role: UserTenantRole,
  )
}

pub fn decode_assigned_role(d: Dynamic) {
  let decoder =
    dynamic.decode3(
      UserTenantRoleForAccess,
      dynamic.element(0, tenant.decode_tenant_id),
      dynamic.element(1, dynamic.string),
      dynamic.element(2, decode_role),
    )

  decoder(d)
}

pub fn get_user_tenant_roles(
  db: Connection,
  user_id: UserId,
) -> Result(List(UserTenantRoleForAccess), QueryError) {
  let sql =
    "
      SELECT
        utr.tenant_id,
        t.full_name,
        utr.role_desc
      FROM user_tenant_roles utr
      JOIN tenants t
        ON utr.tenant_id = t.id
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
