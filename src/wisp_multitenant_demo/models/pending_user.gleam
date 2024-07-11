import birl.{type Time}
import birl/duration
import gleam/bit_array
import gleam/bool
import gleam/crypto
import gleam/dynamic.{type Dynamic}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/pgo.{type Connection}
import gleam/result
import wisp
import wisp_multitenant_demo/models/pending_user_tenant_role
import wisp_multitenant_demo/models/user
import wisp_multitenant_demo/models/user_tenant_role
import wisp_multitenant_demo/types/email.{type Email}
import wisp_multitenant_demo/types/password.{type Password}
import wisp_multitenant_demo/types/time

pub type PendingUser {
  PendingUser(email_address: Email, invited_at: Time, expires_at: Time)
}

pub fn decode_pending_user_sql(d: Dynamic) {
  let decoder =
    dynamic.decode3(
      PendingUser,
      dynamic.element(0, email.decode_email),
      dynamic.element(1, time.dynamic_time),
      dynamic.element(2, time.dynamic_time),
    )

  decoder(d)
}

pub type PendingUserToken {
  PendingUserToken(value: String)
}

const default_invite_duration_minutes = 15

pub fn create(
  db: Connection,
  email: Email,
) -> Result(PendingUserToken, pgo.QueryError) {
  let sql =
    "
        INSERT INTO pending_users
        (email_address, token_hash, expires_at)
        VALUES
        ($1, $2, $3)
        ON CONFLICT (email_address)
        DO UPDATE SET
            token_hash = $2,
            expires_at = $3;
    "

  let invite_token = wisp.random_string(32)
  let token_hash =
    crypto.hash(crypto.Sha256, invite_token |> bit_array.from_string())

  let now = birl.utc_now()
  let expiration =
    now |> birl.add(duration.minutes(default_invite_duration_minutes))

  use _ <- result.try({
    pgo.execute(
      sql,
      db,
      [
        email |> email.to_string() |> pgo.text(),
        token_hash |> pgo.bytea(),
        expiration |> birl.to_erlang_universal_datetime() |> pgo.timestamp(),
      ],
      dynamic.dynamic,
    )
  })

  Ok(PendingUserToken(invite_token))
}

pub fn remove_invite_by_email(
  db: Connection,
  email: email.Email,
) -> Result(Nil, pgo.QueryError) {
  let sql =
    "
        DELETE FROM pending_users
        WHERE email_address = $1;
    "

  use _ <- result.try({
    pgo.execute(
      sql,
      db,
      [email |> email.to_string() |> pgo.text()],
      dynamic.dynamic,
    )
  })

  Ok(Nil)
}

pub fn get_active_invite_by_token(
  conn: Connection,
  invite_token: String,
) -> Result(Option(PendingUser), pgo.QueryError) {
  let hash = crypto.hash(crypto.Sha256, bit_array.from_string(invite_token))

  let sql =
    "
        SELECT
            email_address,
            invited_at::text,
            expires_at::text
        FROM pending_users
        WHERE invite_token_hash = $1
            AND expires_at > now()
    "

  use result <- result.try({
    pgo.execute(sql, conn, [hash |> pgo.bytea()], decode_pending_user_sql)
  })

  case result.rows {
    [pending_user] -> Ok(Some(pending_user))
    _ -> Ok(None)
  }
}

pub fn try_redeem_invite(
  conn: Connection,
  invite_token: String,
  password: password.Password,
) -> Result(Option(user.User), pgo.TransactionError) {
  use conn <- pgo.transaction(conn)

  let assert Ok(pending) = get_active_invite_by_token(conn, invite_token)

  use <- bool.guard(option.is_none(pending), Ok(None))
  let assert Some(pending) = pending

  // TODO: handle if user with this email already exists
  let assert Ok(user) = user.create(conn, pending.email_address, password)
  let assert Ok(Nil) = remove_invite_by_email(conn, pending.email_address)

  let assert Ok(pending_roles) =
    pending_user_tenant_role.get_pending_roles_by_email(
      conn,
      user.email_address,
    )
  case list.is_empty(pending_roles) {
    True -> Nil
    False -> {
      // TODO optimize
      list.each(pending_roles, fn(role) {
        let assert Ok(Nil) =
          user_tenant_role.set_user_tenant_role(
            conn,
            user.id,
            role.tenant_id,
            role.role,
          )
      })

      let assert Ok(Nil) =
        pending_user_tenant_role.delete_pending_roles_by_email(
          conn,
          user.email_address,
        )
      Nil
    }
  }

  Ok(Some(user))
}
