import gleam/dynamic.{type Dynamic, decode2, element, int, string}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/pgo.{type Connection, type QueryError}
import gleam/result

pub opaque type TenantId {
  TenantId(value: Int)
}

pub fn tenant_id(value: Int) -> TenantId {
  TenantId(value)
}

pub fn id_to_int(id: TenantId) -> Int {
  id.value
}

/// Thoughts:
/// Some multi-applications will also have a 'short name' concept.
/// This would be an application-unique text ID that can be used
/// in place of the primary key.
/// You could use this for say, a tenant-specific subdomain.
/// Ommitted for now, for simplicity.
pub type Tenant {
  Tenant(id: TenantId, full_name: String)
}

pub fn create(db: Connection, full_name: String) -> Result(Tenant, QueryError) {
  let sql =
    "
      INSERT INTO tenants
      (full_name)
      VALUES
      ($1)
      RETURNING id, full_name;
    "

  use response <- result.try({
    pgo.execute(sql, db, [full_name |> pgo.text], decode_tenant_sql)
  })

  let assert Ok(tenant) = list.first(response.rows)
  Ok(tenant)
}

pub fn decode_tenant_id(d: Dynamic) {
  use value <- result.try(int(d))
  Ok(TenantId(value))
}

fn decode_tenant_sql(d: Dynamic) {
  let decoder =
    decode2(Tenant, element(0, decode_tenant_id), element(1, string))

  decoder(d)
}

pub fn get_by_id(
  db: Connection,
  id: TenantId,
) -> Result(Option(Tenant), QueryError) {
  let sql =
    "
      SELECT
        id,
        full_name
      FROM tenants
      WHERE id = $1;
    "

  use response <- result.try({
    pgo.execute(sql, db, [id.value |> pgo.int], decode_tenant_sql)
  })

  case response.rows {
    [tenant] -> Ok(Some(tenant))
    _ -> Ok(None)
  }
}

pub fn get_by_ids(
  db: Connection,
  ids: List(TenantId),
) -> Result(List(Tenant), QueryError) {
  let sql =
    "
      SELECT
        id,
        full_name
      FROM tenants
      WHERE id IN $1;
    "

  use response <- result.try({
    pgo.execute(
      sql,
      db,
      [ids |> list.map(fn(id) { id.value }) |> pgo.array()],
      decode_tenant_sql,
    )
  })

  Ok(response.rows)
}
