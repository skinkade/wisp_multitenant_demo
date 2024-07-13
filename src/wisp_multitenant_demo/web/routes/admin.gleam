import formal/form
import gleam/bool
import gleam/http
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/pgo
import gleam/result
import lustre/attribute.{type Attribute, attribute}
import lustre/element.{type Element, element}
import lustre/element/html.{text}
import wisp
import wisp_multitenant_demo/models/pending_user_tenant_role
import wisp_multitenant_demo/models/tenant
import wisp_multitenant_demo/models/user
import wisp_multitenant_demo/models/user_tenant_role.{
  type UserTenantRole, TenantAdmin, TenantMember, TenantOwner, role_from_string,
  role_to_string,
}
import wisp_multitenant_demo/types/email
import wisp_multitenant_demo/web/middleware
import wisp_multitenant_demo/web/templates/base_templates
import wisp_multitenant_demo/web/web

pub fn admin_router(
  req: wisp.Request,
  app_ctx: web.AppContext,
  req_ctx: web.RequestContext,
) -> wisp.Response {
  use <- middleware.require_one_of_tenant_roles(req_ctx, [
    TenantOwner,
    TenantAdmin,
  ])

  io.debug(wisp.path_segments(req))

  case wisp.path_segments(req) |> list.drop(1) {
    ["manage-users"] -> manage_users_handler(req, app_ctx, req_ctx)
    ["manage-users", "add"] -> add_user_handler(req, app_ctx, req_ctx)
    _ -> wisp.not_found()
  }
}

fn add_user_perm_form(form) {
  html.tr([], [
    html.form(
      [attribute.method("post"), attribute.action("/admin/manage-users/add")],
      [
        html.td([], [
          html.div(
            [
              attribute.class(
                "input input-bordered flex items-center gap-4 mb-2",
              ),
            ],
            [
              html.svg(
                [
                  attribute.class("h-4 w-4 opacity-70"),
                  attribute("fill", "currentColor"),
                  attribute("viewBox", "0 0 16 16"),
                  attribute("xmlns", "http://www.w3.org/2000/svg"),
                ],
                [
                  element(
                    "path",
                    [
                      attribute(
                        "d",
                        "M2.5 3A1.5 1.5 0 0 0 1 4.5v.793c.026.009.051.02.076.032L7.674 8.51c.206.1.446.1.652 0l6.598-3.185A.755.755 0 0 1 15 5.293V4.5A1.5 1.5 0 0 0 13.5 3h-11Z",
                      ),
                    ],
                    [],
                  ),
                  element(
                    "path",
                    [
                      attribute(
                        "d",
                        "M15 6.954 8.978 9.86a2.25 2.25 0 0 1-1.956 0L1 6.954V11.5A1.5 1.5 0 0 0 2.5 13h11a1.5 1.5 0 0 0 1.5-1.5V6.954Z",
                      ),
                    ],
                    [],
                  ),
                ],
              ),
              html.input([
                attribute.placeholder("awesomeperson@example.com"),
                attribute.class("grow"),
                attribute.type_("email"),
                attribute.name("add_user_email"),
                attribute.required(True),
                attribute.value(form.value(form, "add_user_email")),
                attribute.autocomplete("off"),
              ]),
            ],
          ),
        ]),
        html.td([], [
          html.select(
            [
              attribute.name("role_desc"),
              attribute.class("select select-bordered w-full max-w-xs"),
            ],
            [
              html.option(
                [attribute.disabled(True), attribute.selected(True)],
                "Role",
              ),
              ..list.map([TenantMember, TenantAdmin], fn(role) {
                html.option(
                  [attribute.value(role |> role_to_string)],
                  role |> role_to_string,
                )
              })
            ],
          ),
        ]),
        html.td([], [
          html.button(
            [attribute.class("btn btn-primary"), attribute.type_("submit")],
            [html.text("Add User")],
          ),
        ]),
      ],
    ),
  ])
}

pub fn manage_users_handler(
  req: wisp.Request,
  app_ctx: web.AppContext,
  req_ctx: web.RequestContext,
) -> wisp.Response {
  use <- bool.lazy_guard(req.method != http.Get, fn() {
    wisp.method_not_allowed([http.Get])
  })

  use tenant <- middleware.require_selected_tenant(req_ctx)

  let users = user_tenant_role.get_tenant_users(app_ctx.db, tenant)
  use <- bool.lazy_guard(result.is_error(users), fn() {
    io.debug(users)
    wisp.internal_server_error()
  })
  let assert Ok(users) = users

  let add_user_form = form.new()

  base_templates.default("Users", req_ctx, [
    html.div([attribute.class("flex justify-center p-4 xs:mt-8 sm:mt-16")], [
      html.div(
        [attribute.class("flex flex-col justify-center grow max-w-screen-md")],
        [
          html.h1([attribute.class("text-xl font-bold mb-2 pl-1")], [
            element.text("Users"),
          ]),
          html.div([attribute.class("border rounded drop-shadow-sm p-4")], [
            html.table([attribute.class("table table-zebra")], [
              html.thead([], [
                html.tr([], [
                  html.th([], [text("Email")]),
                  html.th([], [text("Role")]),
                  html.th([], []),
                ]),
              ]),
              html.tbody(
                [],
                users
                  |> list.map(fn(user) {
                    html.tr([], [
                      html.td([], [
                        text(user.email_address |> email.to_string()),
                      ]),
                      html.td([], [
                        text(user.role |> user_tenant_role.role_to_string()),
                      ]),
                      html.td([], [
                        case user.is_pending {
                          True ->
                            html.div(
                              [
                                attribute.class(
                                  "rounded-lg bg-warning py-1 px-2 max-w-fit",
                                ),
                              ],
                              [
                                html.span(
                                  [
                                    attribute.class(
                                      "text-sm text-warning-content",
                                    ),
                                  ],
                                  [html.text("pending")],
                                ),
                              ],
                            )

                          False -> element.none()
                        },
                      ]),
                    ])
                  })
                  |> list.append([add_user_perm_form(add_user_form)]),
              ),
            ]),
          ]),
        ],
      ),
    ]),
  ])
  |> wisp.html_response(200)
}

type AddUserSubmission {
  AddUserSubmission(email: email.Email, role: UserTenantRole)
}

fn try_add_user(
  app_ctx: web.AppContext,
  tenant_id: tenant.TenantId,
  submission: AddUserSubmission,
) {
  use db <- pgo.transaction(app_ctx.db)

  let assert Ok(existing) = user.get_by_email(db, submission.email)
  case existing {
    Some(user) -> {
      let assert Ok(_) =
        user_tenant_role.set_user_tenant_role(
          db,
          user.id,
          tenant_id,
          submission.role,
        )
      Nil
    }
    None -> {
      let assert Ok(_) =
        pending_user_tenant_role.create_pending_user_tenant_role(
          db,
          submission.email,
          tenant_id,
          submission.role,
        )
      Nil
    }
  }

  Ok(Nil)
}

fn add_user_handler(
  req: wisp.Request,
  app_ctx: web.AppContext,
  req_ctx: web.RequestContext,
) -> wisp.Response {
  use <- bool.lazy_guard(req.method != http.Post, fn() {
    wisp.method_not_allowed([http.Post])
  })

  use tenant <- middleware.require_selected_tenant(req_ctx)

  use formdata <- wisp.require_form(req)

  let result =
    form.decoding({
      use email <- form.parameter
      use role <- form.parameter
      AddUserSubmission(email: email, role: role)
    })
    |> form.with_values(formdata.values)
    |> form.field("add_user_email", form.string |> form.and(email.parse))
    |> form.field(
      "role_desc",
      form.string
        |> form.and(role_from_string),
    )
    |> form.finish

  case result {
    // The form was valid! Do something with the data and render a page to the user
    Ok(data) -> {
      case try_add_user(app_ctx, tenant, data) {
        Error(_) -> wisp.internal_server_error()
        Ok(_) -> wisp.redirect("/admin/manage-users")
      }
    }

    // The form was invalid. Render the HTML form again with the errors
    Error(form) -> {
      wisp.bad_request()
    }
  }
}
