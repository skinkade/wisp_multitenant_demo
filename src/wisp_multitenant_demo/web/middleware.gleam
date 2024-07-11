import gleam/bool
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/pgo
import gleam/result
import wisp.{type Request, type Response}
import wisp_multitenant_demo/models/tenant
import wisp_multitenant_demo/models/tenant_user_role
import wisp_multitenant_demo/models/user
import wisp_multitenant_demo/models/user_session
import wisp_multitenant_demo/web/web

pub fn derive_session(
  req: Request,
  conn: pgo.Connection,
  handler: fn(Option(user_session.SessionQueryRecord)) -> Response,
) -> Response {
  let session = wisp.get_cookie(req, "session", wisp.Signed)
  use <- bool.guard(result.is_error(session), handler(None))

  let assert Ok(session) = session
  let session = user_session.get_by_session_key_string(conn, session)
  use <- bool.guard(result.is_error(session), wisp.internal_server_error())

  let assert Ok(session) = session
  use <- bool.guard(option.is_none(session), handler(None))

  let assert Some(session) = session
  use <- bool.guard(user_session.is_expired(session), handler(None))

  handler(Some(session))
}

pub fn derive_user(
  req: Request,
  conn: pgo.Connection,
  handler: fn(Option(user.User)) -> Response,
) -> Response {
  use session <- derive_session(req, conn)
  use <- bool.guard(option.is_none(session), handler(None))

  let assert Some(session) = session
  let user = user.get_by_id(conn, session.user_id)
  use <- bool.guard(result.is_error(user), wisp.internal_server_error())

  let assert Ok(Some(user)) = user
  //   use <- bool.guard(user.disabled_or_locked(user), handler(None))

  handler(Some(user))
}

pub fn derive_user_tenant_roles(
  conn: pgo.Connection,
  user: Option(user.User),
  handler: fn(Option(List(tenant_user_role.UserTenantRole))) -> Response,
) -> Response {
  use <- bool.guard(option.is_none(user), handler(None))
  let assert Some(user) = user

  case tenant_user_role.get_user_tenant_roles(conn, user.id) {
    Error(_) -> wisp.internal_server_error()
    Ok(roles) -> handler(Some(roles))
  }
}

pub fn require_user(
  req_ctx: web.RequestContext,
  handler: fn(user.User) -> Response,
) -> Response {
  use <- bool.guard(option.is_none(req_ctx.user), wisp.redirect("/login"))
  let assert Some(user) = req_ctx.user
  handler(user)
}

pub fn require_tenant_access(
  req_ctx: web.RequestContext,
  tenant_id: tenant.TenantId,
  handler: fn() -> Response,
) -> Response {
  use <- bool.guard(
    option.is_none(req_ctx.user_tenant_roles),
    wisp.redirect("/login"),
  )
  let assert Some(user_tenant_roles) = req_ctx.user_tenant_roles

  use <- bool.guard(
    !{
      user_tenant_roles
      |> list.map(fn(utr) { utr.tenant_id })
      |> list.contains(tenant_id)
    },
    wisp.response(500),
  )

  handler()
}

pub fn require_selected_tenant(
  req: wisp.Request,
  req_ctx: web.RequestContext,
  handler: fn(tenant.TenantId) -> Response,
) -> Response {
  let tenant_id = {
    use value <- result.try(wisp.get_cookie(req, "tenant", wisp.Signed))
    let assert Ok(value) = int.parse(value)
    Ok(tenant.tenant_id(value))
  }

  use <- bool.guard(result.is_error(tenant_id), wisp.redirect("/"))
  let assert Ok(tenant_id) = tenant_id

  use <- require_tenant_access(req_ctx, tenant_id)

  handler(tenant_id)
}
