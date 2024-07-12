import gleam/option.{type Option}
import gleam/pgo
import wisp
import wisp_multitenant_demo/models/tenant
import wisp_multitenant_demo/models/user
import wisp_multitenant_demo/models/user_tenant_role.{
  type UserTenantRoleForAccess,
}
import wisp_multitenant_demo/types/email

pub type AppContext {
  AppContext(
    db: pgo.Connection,
    static_directory: String,
    send_email: fn(email.EmailMessage) -> Result(Nil, String),
  )
}

/// Thought: maybe roles should be non-null,
/// defaulting to an empty array
pub type RequestContext {
  RequestContext(
    user: Option(user.User),
    user_tenant_roles: Option(List(UserTenantRoleForAccess)),
    selected_tenant_id: Option(tenant.TenantId),
  )
}

pub fn middleware(
  req: wisp.Request,
  app_ctx: AppContext,
  _req_ctx: RequestContext,
  handle_request: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  let req = wisp.method_override(req)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)
  use <- wisp.serve_static(
    req,
    under: "/static",
    from: app_ctx.static_directory,
  )

  handle_request(req)
}
