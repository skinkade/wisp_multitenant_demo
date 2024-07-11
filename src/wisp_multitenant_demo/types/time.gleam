import birl
import gleam/dynamic.{type Dynamic, DecodeError}
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
