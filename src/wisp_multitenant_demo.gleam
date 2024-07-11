import gleam/erlang/process
import gleam/option.{Some}
import gleam/pgo
import mist
import wisp
import wisp_multitenant_demo/types/email
import wisp_multitenant_demo/web/router
import wisp_multitenant_demo/web/web

pub fn main() {
  wisp.configure_logger()
  let secret_key_base = wisp.random_string(64)

  let db =
    pgo.connect(
      pgo.Config(
        ..pgo.default_config(),
        host: "localhost",
        password: Some("postgres"),
        database: "wisp_multitenant_demo",
        pool_size: 15,
      ),
    )

  let app_ctx =
    web.AppContext(
      db: db,
      static_directory: static_directory(),
      send_email: email.print_email_message,
    )

  let handler = router.handle_request(_, app_ctx)

  let assert Ok(_) =
    handler
    |> wisp.mist_handler(secret_key_base)
    |> mist.new
    |> mist.port(8000)
    |> mist.start_http

  process.sleep_forever()
}

pub fn static_directory() -> String {
  let assert Ok(priv_directory) = wisp.priv_directory("wisp_multitenant_demo")
  priv_directory <> "/static"
}
