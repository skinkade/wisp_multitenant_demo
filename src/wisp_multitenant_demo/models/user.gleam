import birl.{type Time}
import gleam/dynamic.{type Dynamic}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/pgo.{type Connection}
import gleam/result
import wisp_multitenant_demo/types/email.{type Email}
import wisp_multitenant_demo/types/password.{type Password}
import wisp_multitenant_demo/types/time

pub type UserId {
  UserId(value: Int)
}

pub fn id_to_int(id: UserId) -> Int {
  id.value
}

pub fn decode_user_id(d: Dynamic) {
  use value <- result.try(dynamic.int(d))
  Ok(UserId(value))
}

pub type User {
  User(
    id: UserId,
    email_address: Email,
    password_hash: String,
    created_at: Time,
  )
}

pub fn decode_user_sql(d: Dynamic) {
  let decoder =
    dynamic.decode4(
      User,
      dynamic.element(0, decode_user_id),
      dynamic.element(1, email.decode_email),
      dynamic.element(2, dynamic.string),
      dynamic.element(3, time.dynamic_time),
    )

  decoder(d)
}

pub fn create(
  db: Connection,
  email: Email,
  password: Password,
) -> Result(User, pgo.QueryError) {
  let sql =
    "
        INSERT INTO users
        (email_address, password_hash)
        VALUES
        ($1, $2)
        RETURNING
            id,
            email_address,
            password_hash,
            created_at::text;
    "

  let password_hash = password.hash(password)

  use response <- result.try({
    pgo.execute(
      sql,
      db,
      [email |> email.to_string() |> pgo.text(), password_hash |> pgo.text()],
      decode_user_sql,
    )
  })

  let assert Ok(user) = list.first(response.rows)
  Ok(user)
}

pub fn get_by_id(
  conn: Connection,
  id: UserId,
) -> Result(Option(User), pgo.QueryError) {
  let sql =
    "
    SELECT
        id,
        email_address,
        password_hash,
        created_at::text
    FROM users
    WHERE id = $1
  "

  use result <- result.try({
    pgo.execute(sql, conn, [id.value |> pgo.int()], decode_user_sql)
  })

  case result.rows {
    [] -> Ok(None)
    [user] -> Ok(Some(user))
    _ -> panic as "Unreachable"
  }
}

pub fn get_by_ids(
  conn: Connection,
  ids: List(UserId),
) -> Result(List(User), pgo.QueryError) {
  let sql =
    "
    SELECT
        id,
        email_address,
        password_hash,
        created_at::text
    FROM users
    WHERE id IN $1
  "

  use result <- result.try({
    pgo.execute(
      sql,
      conn,
      [ids |> list.map(fn(id) { id.value }) |> pgo.array()],
      decode_user_sql,
    )
  })

  Ok(result.rows)
}

pub fn get_by_email(
  conn: Connection,
  email: Email,
) -> Result(Option(User), pgo.QueryError) {
  let sql =
    "
    SELECT
        id,
        email_address,
        password_hash,
        created_at::text
    FROM users
    WHERE email_address = $1
  "

  use result <- result.try({
    pgo.execute(
      sql,
      conn,
      [email |> email.to_string() |> pgo.text()],
      decode_user_sql,
    )
  })

  case result.rows {
    [] -> Ok(None)
    [user] -> Ok(Some(user))
    _ -> panic as "Unreachable"
  }
}
