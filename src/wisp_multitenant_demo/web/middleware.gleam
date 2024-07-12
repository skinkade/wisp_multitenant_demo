import gleam/bool
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/pgo
import gleam/result
import wisp.{type Request, type Response}
import wisp_multitenant_demo/models/tenant
import wisp_multitenant_demo/models/user
import wisp_multitenant_demo/models/user_session
import wisp_multitenant_demo/models/user_tenant_role
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
  handler: fn(Option(List(user_tenant_role.UserTenantRoleForAccess))) ->
    Response,
) -> Response {
  use <- bool.guard(option.is_none(user), handler(None))
  let assert Some(user) = user

  case user_tenant_role.get_user_tenant_roles(conn, user.id) {
    Error(e) -> {
      io.debug(e)
      wisp.internal_server_error()
    }
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

// pub fn require_tenant_access(
//   req_ctx: web.RequestContext,
//   tenant_id: tenant.TenantId,
//   handler: fn() -> Response,
// ) -> Response {
//   use <- bool.guard(
//     option.is_none(req_ctx.user_tenant_roles),
//     wisp.redirect("/login"),
//   )
//   let assert Some(user_tenant_roles) = req_ctx.user_tenant_roles

//   use <- bool.guard(
//     !{
//       user_tenant_roles
//       |> list.map(fn(utr) { utr.tenant_id })
//       |> list.contains(tenant_id)
//     },
//     wisp.response(500),
//   )

//   handler()
// }

pub fn derive_selected_tenant(
  req,
  handler: fn(Option(tenant.TenantId)) -> Response,
) -> Response {
  let tenant_id = {
    let query_value = wisp.get_query(req) |> list.key_find("tenantId")
    case query_value {
      Ok(query_value) -> {
        case int.parse(query_value) {
          Ok(query_value) -> Ok(tenant.tenant_id(query_value))
          Error(_) -> Error(Nil)
        }
      }
      Error(_) -> {
        use cookie_value <- result.try(wisp.get_cookie(
          req,
          "tenant",
          wisp.Signed,
        ))
        let assert Ok(cookie_value) = int.parse(cookie_value)
        Ok(tenant.tenant_id(cookie_value))
      }
    }
  }

  case tenant_id {
    Ok(tenant_id) ->
      handler(Some(tenant_id))
      |> wisp.set_cookie(
        req,
        "tenant",
        tenant_id |> tenant.id_to_int() |> int.to_string(),
        wisp.Signed,
        60 * 60 * 24,
      )
    Error(_) -> handler(None)
  }
}

pub fn tenant_auth(
  req: Request,
  req_ctx: web.RequestContext,
  handler: fn(web.RequestContext) -> Response,
) -> Response {
  use <- bool.guard(
    option.is_none(req_ctx.user_tenant_roles),
    handler(web.RequestContext(..req_ctx, selected_tenant_id: None)),
  )
  let assert Some(roles) = req_ctx.user_tenant_roles

  case req_ctx.selected_tenant_id, roles {
    // if only one tenant allowed, default to that
    None, [role] ->
      handler(
        web.RequestContext(..req_ctx, selected_tenant_id: Some(role.tenant_id)),
      )
    None, _ -> handler(req_ctx)
    Some(selection), roles -> {
      use <- bool.guard(
        !{
          roles
          |> list.map(fn(utr) { utr.tenant_id })
          |> list.contains(selection)
        },
        wisp.redirect("/demo")
          |> wisp.set_cookie(req, "tenant", "", wisp.Signed, 0),
      )
      handler(req_ctx)
    }
  }
}

pub fn require_selected_tenant(
  req: wisp.Request,
  req_ctx: web.RequestContext,
  handler: fn(tenant.TenantId) -> Response,
) -> Response {
  use <- bool.guard(
    option.is_none(req_ctx.selected_tenant_id),
    wisp.redirect("/"),
  )

  let assert Some(tenant_id) = req_ctx.selected_tenant_id

  handler(tenant_id)
}
