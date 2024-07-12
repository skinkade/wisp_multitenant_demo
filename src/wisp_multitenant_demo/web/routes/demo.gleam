import gleam/io
import lustre/attribute
import lustre/element/html
import wisp.{type Request, type Response}
import wisp_multitenant_demo/types/email
import wisp_multitenant_demo/web/middleware
import wisp_multitenant_demo/web/templates/base_templates
import wisp_multitenant_demo/web/web

pub fn demo_handler(
  _req: Request,
  app_ctx: web.AppContext,
  req_ctx: web.RequestContext,
) -> Response {
  use user <- middleware.require_user(req_ctx)

  base_templates.default("Welcome!", req_ctx, [
    html.div([attribute.class("flex justify-center p-4 xs:mt-8 sm:mt-16")], [
      html.div(
        [
          attribute.class(
            "min-w-96 max-w-96 border rounded drop-shadow-sm p-4 flex flex-col justify-center",
          ),
        ],
        [
          html.span([], [
            html.text("Welcome, " <> email.to_string(user.email_address)),
          ]),
        ],
      ),
    ]),
  ])
  |> wisp.html_response(200)
}
