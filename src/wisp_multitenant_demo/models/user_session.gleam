import birl.{type Time}
import birl/duration
import gleam/bit_array
import gleam/crypto
import gleam/dynamic
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/pgo.{type Connection}
import gleam/result
import wisp
import wisp_multitenant_demo/models/user.{type UserId}
import wisp_multitenant_demo/types/time

const default_session_days = 7

pub opaque type SessionKey {
  SessionKey(value: String)
}

pub type SessionQueryRecord {
  SessionQueryRecord(
    id: Int,
    user_id: UserId,
    created_at: Time,
    expires_at: Time,
  )
}

pub fn key_to_string(session_key: SessionKey) -> String {
  session_key.value
}

pub fn create_with_defaults(
  conn: Connection,
  user_id: UserId,
) -> Result(#(SessionKey, Int), pgo.QueryError) {
  let session_key = wisp.random_string(32)
  let session_hash =
    crypto.hash(crypto.Sha256, bit_array.from_string(session_key))

  // TODO: audit trail
  let sql =
    "
        INSERT INTO user_sessions
        (session_hash, user_id, created_at, expires_at)
        VALUES
        ($1, $2, $3, $4);
    "

  let now = birl.utc_now()
  let expiration = now |> birl.add(duration.days(default_session_days))

  use _ <- result.try({
    pgo.execute(
      sql,
      conn,
      [
        session_hash |> pgo.bytea(),
        user_id |> user.id_to_int() |> pgo.int(),
        now |> birl.to_erlang_universal_datetime() |> pgo.timestamp(),
        expiration |> birl.to_erlang_universal_datetime() |> pgo.timestamp(),
      ],
      dynamic.dynamic,
    )
  })

  let seconds_until_expiration = default_session_days * 24 * 60 * 60 - 1

  Ok(#(SessionKey(session_key), seconds_until_expiration))
}

fn decode_session_record(d: dynamic.Dynamic) {
  let decoder =
    dynamic.decode4(
      SessionQueryRecord,
      dynamic.element(0, dynamic.int),
      dynamic.element(1, user.decode_user_id),
      dynamic.element(2, time.dynamic_time),
      dynamic.element(3, time.dynamic_time),
    )

  decoder(d)
}

pub fn get_by_session_key_string(
  conn: Connection,
  key: String,
) -> Result(Option(SessionQueryRecord), pgo.QueryError) {
  let hash = crypto.hash(crypto.Sha256, bit_array.from_string(key))

  let sql =
    "
        SELECT
            id,
            user_id,
            created_at::text,
            expires_at::text
        FROM user_sessions
        WHERE session_hash = $1
    "

  use result <- result.try({
    pgo.execute(sql, conn, [hash |> pgo.bytea()], decode_session_record)
  })

  case result.rows {
    [session] -> Ok(Some(session))
    _ -> Ok(None)
  }
}

pub fn is_expired(session: SessionQueryRecord) -> Bool {
  case birl.compare(birl.utc_now(), session.expires_at) {
    order.Gt -> True
    _ -> False
  }
}
