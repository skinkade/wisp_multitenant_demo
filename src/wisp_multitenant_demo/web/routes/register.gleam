import formal/form.{type Form}
import gleam/bool
import gleam/dict
import gleam/http.{Get, Post}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/string_builder.{type StringBuilder}
import lustre
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html
import wisp.{type Request, type Response}
import wisp_multitenant_demo/models/pending_user
import wisp_multitenant_demo/models/user_session
import wisp_multitenant_demo/types/email
import wisp_multitenant_demo/types/password
import wisp_multitenant_demo/web/templates/base_templates
import wisp_multitenant_demo/web/web

pub fn register_handler(
  req: Request,
  app_ctx: web.AppContext,
  req_ctx: web.RequestContext,
) {
  case req.method {
    Get -> register_form(req_ctx)
    Post -> submit_register_form(req, app_ctx, req_ctx)
    _ -> wisp.method_not_allowed([Get, Post])
  }
}

pub fn confirm_handler(
  req: Request,
  app_ctx: web.AppContext,
  req_ctx: web.RequestContext,
) {
  case req.method {
    Get -> confirmation_form(req, app_ctx, req_ctx)
    Post -> submit_confirmation_form(req, app_ctx, req_ctx)
    _ -> wisp.method_not_allowed([Get, Post])
  }
}

fn register_form(req_ctx) -> Response {
  // Create a new empty Form to render the HTML form with.
  // If the form is for updating something that already exists you may want to
  // use `form.initial_values` to pre-fill some fields.
  let form = form.new()

  base_templates.default("Register", req_ctx, [render_register_form(form, None)])
  |> wisp.html_response(200)
}

fn submit_register_form(
  req: Request,
  app_ctx: web.AppContext,
  req_ctx: web.RequestContext,
) -> Response {
  use formdata <- wisp.require_form(req)

  let result =
    form.decoding({
      use email <- form.parameter
      email
    })
    |> form.with_values(formdata.values)
    |> form.field("email", form.string |> form.and(email.parse))
    |> form.finish

  case result {
    Ok(email) -> {
      case pending_user.create(app_ctx.db, email) {
        Ok(pending_user_token) -> {
          let email_attempt =
            create_invite_email(email, pending_user_token)
            |> app_ctx.send_email()
          case email_attempt {
            Error(e) -> {
              io.debug(e)
              base_templates.base_html("Register", [
                render_register_form(
                  form.new(),
                  Some("An error occurred trying to create your account"),
                ),
              ])
              |> wisp.html_response(500)
            }
            Ok(Nil) -> {
              base_templates.default("Register", req_ctx, [
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
                        html.h1(
                          [attribute.class("text-xl font-bold mb-2 pl-1")],
                          [element.text("Register")],
                        ),
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
        Error(e) -> {
          io.debug(e)
          base_templates.base_html("Register", [
            render_register_form(
              form.new(),
              Some("An error occurred trying to create your account"),
            ),
          ])
          |> wisp.html_response(500)
        }
      }
    }

    Error(form) -> {
      base_templates.base_html("Register", [render_register_form(form, None)])
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
          element.text("Register New User"),
        ]),
        html.div([attribute.class("border rounded drop-shadow-sm p-4")], [
          html.form([attribute.method("post")], [
            base_templates.email_input(form, "email", False),
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

pub fn create_invite_email(
  address: email.Email,
  token: pending_user.PendingUserToken,
) {
  let link = "http://localhost:8000/register/confirm?token=" <> token.value
  let body =
    html.html([attribute.attribute("lang", "en")], [
      html.head([], [
        html.meta([attribute.attribute("charset", "UTF-8")]),
        html.meta([
          attribute.attribute("name", "viewport"),
          attribute.attribute(
            "content",
            "width=device-width, initial-scale=1.0",
          ),
        ]),
      ]),
      html.body([], [html.a([attribute.href(link)], [html.text(link)])]),
    ])
    |> element.to_string

  email.EmailMessage(
    recipients: [address],
    subject: "Wisp Multi-Tenant Demo Registration Link",
    body: body,
  )
}

fn query_token(req) {
  req |> wisp.get_query() |> list.key_find("token")
}

fn confirmation_form(
  req: Request,
  app_ctx: web.AppContext,
  req_ctx: web.RequestContext,
) -> Response {
  let token = query_token(req)
  use <- bool.guard(
    result.is_error(token),
    invalid_or_expired_confirmation_token(req_ctx),
  )
  let assert Ok(token) = token

  let invite = pending_user.get_active_invite_by_token(app_ctx.db, token)
  use <- bool.guard(result.is_error(invite), wisp.internal_server_error())

  let assert Ok(invite) = invite
  use <- bool.guard(
    option.is_none(invite),
    invalid_or_expired_confirmation_token(req_ctx),
  )

  let assert Some(invite) = invite
  let form =
    form.initial_values([
      #("token", token),
      #("email", email.to_string(invite.email_address)),
    ])

  base_templates.base_html("Confirm Registration", [
    render_confirmation_form(form, None),
  ])
  |> wisp.html_response(200)
}

fn render_confirmation_form(form: Form, error: Option(String)) {
  html.div([attribute.class("flex justify-center p-4 xs:mt-8 sm:mt-16")], [
    html.div(
      [attribute.class("min-w-96 max-w-96 flex flex-col justify-center")],
      [
        html.h1([attribute.class("text-xl font-bold mb-2 pl-1")], [
          element.text("Register New User"),
        ]),
        html.div([attribute.class("border rounded drop-shadow-sm p-4")], [
          html.form([attribute.method("post")], [
            base_templates.email_input(form, "email", True),
            base_templates.password_input(form, "password"),
            html.input([
              attribute.type_("hidden"),
              attribute.name("token"),
              attribute.value(form.value(form, "token")),
            ]),
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

pub type ConfirmationSubmission {
  ConfirmationSubmission(token: String, password: password.Password)
}

fn invalid_or_expired_confirmation_token(app_ctx) {
  base_templates.default("Invalid Registration Link", app_ctx, [
    html.div([attribute.class("flex justify-center p-4 xs:mt-8 sm:mt-16")], [
      html.div(
        [attribute.class("min-w-96 max-w-96 flex flex-col justify-center")],
        [
          html.h1([attribute.class("text-xl font-bold mb-2 pl-1")], [
            element.text("Invalid Registration Link"),
          ]),
          html.div([attribute.class("border rounded drop-shadow-sm p-4")], [
            html.div(
              [
                attribute.class(
                  "alert alert-warning py-2 px-4 text-sm rounded text-center flex flex-col",
                ),
                attribute.role("alert"),
              ],
              [
                html.p([attribute.class("font-bold")], [
                  html.text("This registration link is invalid or has expired."),
                ]),
              ],
            ),
          ]),
        ],
      ),
    ]),
  ])
  |> wisp.html_response(404)
}

fn submit_confirmation_form(
  req: Request,
  app_ctx: web.AppContext,
  req_ctx: web.RequestContext,
) -> Response {
  let token = query_token(req)
  use <- bool.guard(
    result.is_error(token),
    invalid_or_expired_confirmation_token(req_ctx),
  )
  let assert Ok(token) = token

  let invite = pending_user.get_active_invite_by_token(app_ctx.db, token)
  use <- bool.lazy_guard(result.is_error(invite), fn() {
    io.debug(invite)
    wisp.internal_server_error()
  })

  let assert Ok(invite) = invite
  use <- bool.guard(
    option.is_none(invite),
    invalid_or_expired_confirmation_token(req_ctx),
  )
  let assert Some(invite) = invite

  let password_policy = password.PasswordPolicy(min_length: 12, max_length: 50)
  use formdata <- wisp.require_form(req)

  let result =
    form.decoding({
      use token <- form.parameter
      use password <- form.parameter
      ConfirmationSubmission(token: token, password: password)
    })
    |> form.with_values(formdata.values)
    |> form.field("token", form.string |> form.and(form.must_not_be_empty))
    |> form.field(
      "password",
      form.string
        |> form.and(password.create)
        |> form.and(password.policy_compliant(_, password_policy)),
    )
    |> form.finish

  case result {
    Ok(data) -> {
      case
        pending_user.try_redeem_invite(app_ctx.db, data.token, data.password)
      {
        Ok(user) -> {
          io.debug(user)
          use <- bool.guard(
            option.is_none(user),
            invalid_or_expired_confirmation_token(req_ctx),
          )
          let assert Some(user) = user
          case user_session.create_with_defaults(app_ctx.db, user.id) {
            Ok(#(session_key, seconds_until_expiration)) -> {
              wisp.redirect("/demo")
              |> wisp.set_cookie(
                req,
                "session",
                user_session.key_to_string(session_key),
                wisp.Signed,
                seconds_until_expiration,
              )
            }
            Error(e) -> {
              io.debug(e)
              wisp.internal_server_error()
            }
          }
          // base_templates.default("Confirm Registration", req_ctx, [
          //   html.span([], [html.text("Yay")]),
          // ])
          // |> wisp.html_response(201)
        }
        Error(e) -> {
          io.debug(e)
          base_templates.default("Confirm Registration", req_ctx, [
            render_confirmation_form(
              form.initial_values([
                #("token", token),
                #("email", email.to_string(invite.email_address)),
              ]),
              // form.new(),
              Some("An error occurred trying to create your account"),
            ),
          ])
          |> wisp.html_response(500)
        }
      }
    }

    Error(form) -> {
      io.debug(form)
      let form =
        form.Form(
          values: form.values
            |> dict.insert("email", [email.to_string(invite.email_address)])
            |> dict.insert("token", [token]),
          errors: form.errors,
        )
      base_templates.default("Confirm Registration", req_ctx, [
        render_confirmation_form(form, None),
      ])
      |> wisp.html_response(422)
    }
  }
}
