import formal/form.{type Form}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre
import lustre/attribute.{type Attribute, attribute}
import lustre/element.{type Element, element}
import lustre/element/html.{text}
import wisp_multitenant_demo/models/tenant
import wisp_multitenant_demo/types/email
import wisp_multitenant_demo/web/web

pub fn base_html(title: String, children) {
  html.html([attribute("lang", "en")], [
    html.head([], [
      html.meta([attribute.attribute("charset", "UTF-8")]),
      html.meta([
        attribute.attribute("name", "viewport"),
        attribute.attribute("content", "width=device-width, initial-scale=1.0"),
      ]),
      html.title([], title),
      html.link([
        attribute.rel("stylesheet"),
        attribute.href("/static/css/main.css"),
      ]),
    ]),
    html.body([], children),
  ])
  |> element.to_document_string_builder
}

pub fn default(title: String, req_ctx: web.RequestContext, content) {
  let auth_element = case req_ctx.user {
    Some(user) ->
      html.div([attribute.class("dropdown")], [
        html.div(
          [
            attribute.class("btn m-1"),
            attribute.role("button"),
            attribute("tabindex", "0"),
          ],
          [text(email.to_string(user.email_address))],
        ),
        html.ul(
          [
            attribute.class(
              "dropdown-content menu bg-base-100 rounded-box z-[1] w-52 p-2 shadow",
            ),
            attribute("tabindex", "0"),
          ],
          [html.li([], [html.a([], [text("Logout")])])],
        ),
      ])
    None ->
      html.div([attribute.class("flex-0")], [
        html.a([attribute.href("/login")], [
          html.button([attribute.class("btn"), attribute.type_("button")], [
            html.text("Login"),
          ]),
        ]),
      ])
  }

  let tenant_element = case req_ctx.user_tenant_roles {
    Some([]) -> element.none()
    Some(roles) ->
      html.form([attribute.method("get")], [
        html.select(
          [
            attribute.class("select select-bordered w-full max-w-xs"),
            attribute.attribute("onchange", "this.parentElement.submit()"),
            attribute.name("tenantId"),
          ],
          [
            html.option(
              [
                attribute.disabled(True),
                attribute.selected(option.is_none(req_ctx.selected_tenant_id)),
              ],
              "Select Tenant",
            ),
            ..list.map(roles, fn(role) {
              html.option(
                [
                  attribute.value(
                    role.tenant_id |> tenant.id_to_int() |> int.to_string(),
                  ),
                  attribute.selected(
                    Some(role.tenant_id) == req_ctx.selected_tenant_id,
                  ),
                ],
                role.tenant_full_name,
              )
            })
          ],
        ),
      ])

    _ -> element.none()
  }

  base_html(title, [
    html.header(
      [
        attribute.class(
          "bg-base-100 text-base-content sticky top-0 z-30 flex h-16 w-full justify-center bg-opacity-90 backdrop-blur transition-shadow",
        ),
      ],
      [
        html.nav([attribute.class("navbar w-full")], [
          html.div([attribute.class("flex flex-1 md:gap-1 lg:gap-2")], [
            html.text("Demo"),
          ]),
          html.div([], [tenant_element]),
          html.div([attribute.class("flex-0")], [auth_element]),
        ]),
      ],
    ),
    html.main([attribute.class("container")], content),
  ])
}

pub fn field_error(form, name) {
  let error_element = case form.field_state(form, name) {
    Ok(_) -> element.none()
    Error(message) ->
      html.div(
        [
          attribute.class(
            "alert alert-error py-2 px-4 text-sm rounded text-center",
          ),
          attribute.role("alert"),
        ],
        [html.span([], [text(message)])],
      )
  }

  html.div([attribute.class("min-h-8 mb-2")], [error_element])
}

pub fn form_field(
  form: Form,
  name name: String,
  kind kind: String,
  title title: String,
  attributes additional_attributes: List(Attribute(a)),
) -> Element(a) {
  html.label([], [
    html.div([], [element.text(title)]),
    html.input([
      attribute.type_(kind),
      attribute.name(name),
      attribute.value(form.value(form, name)),
      ..additional_attributes
    ]),
    field_error(form, name),
  ])
}

pub fn form_error(error: Option(String)) {
  let error_element = case error {
    None -> element.none()
    Some(message) ->
      html.div(
        [
          attribute.class(
            "alert alert-error py-2 px-4 text-sm rounded text-center",
          ),
          attribute.role("alert"),
        ],
        [html.span([], [text(message)])],
      )
  }

  html.div([attribute.class("min-h-8 mb-2")], [error_element])
}

pub fn email_input(form: Form, name: String, disabled: Bool) {
  html.div([attribute.class("mb-2")], [
    html.label(
      [attribute.for("password"), attribute.class("font-bold mb-2 pl-1")],
      [
        element.text("Email"),
        html.div(
          [attribute.class("input input-bordered flex items-center gap-4 mb-2")],
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
              attribute.name(name),
              attribute.required(True),
              attribute.value(form.value(form, name)),
              attribute.autocomplete("off"),
              attribute.disabled(disabled),
            ]),
          ],
        ),
      ],
    ),
    field_error(form, name),
  ])
}

pub fn password_input(form: Form, name: String) {
  html.div([attribute.class("mb-2")], [
    html.label(
      [attribute.for("password"), attribute.class("font-bold mb-2 pl-1")],
      [
        element.text("Password"),
        html.div(
          [attribute.class("input input-bordered flex items-center gap-4 mb-2")],
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
                    attribute("clip-rule", "evenodd"),
                    attribute(
                      "d",
                      "M14 6a4 4 0 0 1-4.899 3.899l-1.955 1.955a.5.5 0 0 1-.353.146H5v1.5a.5.5 0 0 1-.5.5h-2a.5.5 0 0 1-.5-.5v-2.293a.5.5 0 0 1 .146-.353l3.955-3.955A4 4 0 1 1 14 6Zm-4-2a.75.75 0 0 0 0 1.5.5.5 0 0 1 .5.5.75.75 0 0 0 1.5 0 2 2 0 0 0-2-2Z",
                    ),
                    attribute("fill-rule", "evenodd"),
                  ],
                  [],
                ),
              ],
            ),
            html.input([
              attribute.placeholder("************"),
              attribute.class("grow"),
              attribute.type_("password"),
              attribute.name(name),
              // attribute.value(form.value(form, name)),
              attribute.autocomplete("off"),
              attribute.required(True),
              // attribute("minlength", "12"),
              attribute("maxlength", "50"),
            ]),
          ],
        ),
      ],
    ),
    field_error(form, name),
  ])
}
