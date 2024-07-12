import gleam/io
import wisp.{type Request, type Response}
import wisp_multitenant_demo/web/middleware
import wisp_multitenant_demo/web/routes/demo
import wisp_multitenant_demo/web/routes/login
import wisp_multitenant_demo/web/routes/register
import wisp_multitenant_demo/web/web

pub fn handle_request(req: Request, app_ctx: web.AppContext) -> Response {
  use user <- middleware.derive_user(req, app_ctx.db)
  use user_tenant_roles <- middleware.derive_user_tenant_roles(app_ctx.db, user)
  use selected_tenant_id <- middleware.derive_selected_tenant(req)

  let req_ctx =
    web.RequestContext(
      user: user,
      user_tenant_roles: user_tenant_roles,
      selected_tenant_id: selected_tenant_id,
    )
  use req <- web.middleware(req, app_ctx, req_ctx)
  // TODO refactor
  use req_ctx <- middleware.tenant_auth(req, req_ctx)

  case wisp.path_segments(req) {
    ["demo"] -> demo.demo_handler(req, app_ctx, req_ctx)
    ["login"] -> login.login_handler(req, app_ctx, req_ctx)
    ["register"] -> register.register_handler(req, app_ctx, req_ctx)
    ["register", "confirm"] -> register.confirm_handler(req, app_ctx, req_ctx)
    _ -> wisp.not_found()
  }
}
