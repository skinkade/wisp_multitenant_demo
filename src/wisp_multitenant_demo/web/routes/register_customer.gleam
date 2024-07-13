import formal/form.{type Form}
import gleam/bool
import gleam/dict
import gleam/http.{Get, Post}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/pgo
import gleam/result
import gleam/string
import gleam/string_builder.{type StringBuilder}
import lustre
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html
import wisp.{type Request, type Response}
import wisp_multitenant_demo/models/pending_user
import wisp_multitenant_demo/models/pending_user_tenant_role
import wisp_multitenant_demo/models/tenant
import wisp_multitenant_demo/models/user_session
import wisp_multitenant_demo/models/user_tenant_role
import wisp_multitenant_demo/types/email
import wisp_multitenant_demo/types/password
import wisp_multitenant_demo/web/middleware
import wisp_multitenant_demo/web/routes/register
import wisp_multitenant_demo/web/templates/base_templates
import wisp_multitenant_demo/web/web

pub fn register_handler(
  req: Request,
  app_ctx: web.AppContext,
  req_ctx: web.RequestContext,
) {
  case req.method {
    Get -> regster_customer_form(req_ctx)
    Post -> submit_register_customer_form(req, app_ctx, req_ctx)
    _ -> wisp.method_not_allowed([Get, Post])
  }
}

fn regster_customer_form(req_ctx) -> Response {
  // Create a new empty Form to render the HTML form with.
  // If the form is for updating something that already exists you may want to
  // use `form.initial_values` to pre-fill some fields.
  let form = form.new()

  base_templates.default("Register", req_ctx, [render_register_form(form, None)])
  |> wisp.html_response(200)
}

fn create_tenant_with_user(
  app_ctx: web.AppContext,
  submission: CustomerRegistrationSubmission,
) {
  use db <- pgo.transaction(app_ctx.db)
  let assert Ok(tenant) = tenant.create(db, submission.company_name)
  let assert Ok(reg_token) = pending_user.create(db, submission.email)
  let assert Ok(_) =
    pending_user_tenant_role.create_pending_user_tenant_role(
      db,
      submission.email,
      tenant.id,
      user_tenant_role.TenantOwner,
    )

  reg_token
  |> register.create_invite_email(submission.email, _)
  |> app_ctx.send_email()

  Ok(Nil)
}

pub type CustomerRegistrationSubmission {
  CustomerRegistrationSubmission(email: email.Email, company_name: String)
}

fn submit_register_customer_form(
  req: Request,
  app_ctx: web.AppContext,
  req_ctx: web.RequestContext,
) -> Response {
  use formdata <- wisp.require_form(req)

  let result =
    form.decoding({
      use company_name <- form.parameter
      use email <- form.parameter
      CustomerRegistrationSubmission(email: email, company_name: company_name)
    })
    |> form.with_values(formdata.values)
    |> form.field(
      "company_name",
      form.string |> form.and(form.must_not_be_empty),
    )
    |> form.field("email", form.string |> form.and(email.parse))
    |> form.finish

  case result {
    Ok(submission) -> {
      case create_tenant_with_user(app_ctx, submission) {
        Error(_) -> wisp.internal_server_error()
        Ok(Nil) -> {
          base_templates.default("Register Customer", req_ctx, [
            html.div(
              [attribute.class("flex justify-center p-4 xs:mt-8 sm:mt-16")],
              [
                html.div(
                  [
                    attribute.class(
                      "min-w-96 max-w-96 flex flex-col justify-center",
                    ),
                  ],
                  [
                    html.h1([attribute.class("text-xl font-bold mb-2 pl-1")], [
                      element.text("Register"),
                    ]),
                    html.div(
                      [attribute.class("border rounded drop-shadow-sm p-4")],
                      [
                        html.p([], [
                          html.text(
                            "A registration link has been sent to your email.",
                          ),
                        ]),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ])
          |> wisp.html_response(201)
        }
      }
    }
    Error(form) -> {
      base_templates.default("Register Customer", req_ctx, [
        render_register_form(form, None),
      ])
      |> wisp.html_response(422)
    }
  }
}

fn render_register_form(form: Form, error: Option(String)) {
  html.div([attribute.class("flex justify-center p-4 xs:mt-8 sm:mt-16")], [
    html.div(
      [attribute.class("min-w-96 max-w-96 flex flex-col justify-center")],
      [
        html.h1([attribute.class("text-xl font-bold mb-2 pl-1")], [
          element.text("Register New Customer"),
        ]),
        html.div([attribute.class("border rounded drop-shadow-sm p-4")], [
          html.form([attribute.method("post")], [
            base_templates.email_input(form, "email", False),
            base_templates.company_name_input(form, "company_name"),
            base_templates.form_error(error),
            html.div([attribute.class("my-4 flex justify-center")], [
              //   html.input([attribute.type_("submit"), attribute.value("Submit")]),
              html.button(
                [attribute.class("btn btn-primary"), attribute.type_("submit")],
                [html.text("Register")],
              ),
            ]),
          ]),
        ]),
      ],
    ),
  ])
}
