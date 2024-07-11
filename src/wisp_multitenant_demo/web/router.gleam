import wisp.{type Request, type Response}
import wisp_multitenant_demo/web/middleware
import wisp_multitenant_demo/web/routes/register
import wisp_multitenant_demo/web/web

pub fn handle_request(req: Request, app_ctx: web.AppContext) -> Response {
  use user <- middleware.derive_user(req, app_ctx.db)
  use user_tenant_roles <- middleware.derive_user_tenant_roles(app_ctx.db, user)

  let req_ctx =
    web.RequestContext(user: user, user_tenant_roles: user_tenant_roles)
  use req <- web.middleware(req, app_ctx, req_ctx)

  case wisp.path_segments(req) {
    ["register"] -> register.register_handler(req, app_ctx, req_ctx)
    ["register", token] ->
      register.confirm_handler(req, app_ctx, req_ctx, token)
    _ -> wisp.not_found()
  }
}
