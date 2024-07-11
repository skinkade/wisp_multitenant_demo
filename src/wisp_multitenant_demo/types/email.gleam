import gleam/bool
import gleam/dynamic.{type DecodeError, type Dynamic, DecodeError}
import gleam/io
import gleam/list
import gleam/result
import gleam/string

pub opaque type Email {
  Email(value: String)
}

// https://thecopenhagenbook.com/email-verification#input-validation
pub fn parse(str: String) -> Result(Email, String) {
  let error = Error("Invalid email")

  let str = string.trim(str)
  use <- bool.guard(string.is_empty(str), error)
  use <- bool.guard(string.length(str) > 255, error)

  use #(head, domain) <- result.try({
    case string.split(str, "@") {
      [head, domain] -> Ok(#(head, domain))
      [head, ..tail] -> {
        use <- bool.guard(list.is_empty(tail), Error("Invalid email"))
        let assert Ok(domain) = list.last(tail)
        Ok(#(head, domain))
      }
      _ -> Error("Invalid email")
    }
  })

  use <- bool.guard(string.is_empty(head), error)
  use <- bool.guard(string.is_empty(domain), error)

  use <- bool.guard(
    {
      case string.split(domain, ".") {
        [_head, ..tail] -> {
          case tail {
            [] -> True
            _ -> False
          }
        }
        _ -> True
      }
    },
    error,
  )

  Ok(Email(str))
}

pub fn to_string(email: Email) -> String {
  email.value
}

pub fn decode_email(d: Dynamic) {
  use str <- result.try(dynamic.string(d))
  case parse(str) {
    Error(_) -> Error([DecodeError(expected: "email", found: "?", path: [])])
    Ok(email) -> Ok(email)
  }
}

pub type EmailMessage {
  EmailMessage(recipients: List(Email), subject: String, body: String)
}

pub fn print_email_message(msg: EmailMessage) -> Result(Nil, String) {
  let recipients = msg.recipients |> list.map(to_string) |> string.join("; ")

  io.println("----- EMAIL -----")
  io.println("To:\t" <> recipients)
  io.println("Subject:\t" <> msg.subject)
  io.println(msg.body)
  io.println("----- END EMAIL -----")

  Ok(Nil)
}
