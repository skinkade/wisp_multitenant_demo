import birl
import gleam/dynamic.{type Dynamic, DecodeError}
import gleam/order
import gleam/result

pub fn dynamic_time(d: Dynamic) {
  // hack
  use ts <- result.try(dynamic.string(d))
  case birl.parse(ts) {
    Error(_) ->
      Error([DecodeError(expected: "timestamp", found: "?", path: [])])
    Ok(time) -> Ok(time)
  }
}

pub fn is_passed(timestamp: birl.Time) -> Bool {
  case birl.compare(birl.utc_now(), timestamp) {
    order.Gt -> True
    _ -> False
  }
}
