# Stratocumulus

Bindings for browser
[`WebSocket`](https://developer.mozilla.org/docs/Web/API/WebSocket/WebSocket)
client constructor. `stratocumulus` can be used anytime low-level bindings on
top of WebSockets are needed. `stratocumulus` has been carefully crafted to be
fully compatible with Gleam data while sticking close with JavaScript, to let
you leverage your JavaScript knowledge. `stratocumulus` does not try to hide the
JavaScript complexity, but rather to provide simple bindings and correct
interface to `WebSocket`.

## Compatibility

`stratocumulus` is compatible with every runtime implementing the standard
JavaScript `WebSocket` object. This means this package is compatible with any
browser, but also with Node (version 22 and higher), Bun or Deno!

## Installation

```sh
gleam add stratocumulus@1
```

## Basic Usage

Open your WebSocket, and subscribe to the different events. To simplify working
with the socket, the `"message"` event handler has been splitted in half: one
for textual content, the other for binary content. The latter will provide a
Gleam `BitArray` to help integrating in the Gleam ecosystem. In any case, the
original event will still be provided in the handler.

```gleam
import gleam/dynamic.{type Dynamic}
import stratocumulus as websocket

pub fn main() {
  let assert Ok(endpoint) = uri.parse("...")
  let assert Ok(ws) =
    websocket.new(endpoint)
    |> websocket.protocols(["soap"])
    |> websocket.on_open(fn (event: Dynamic) { Nil })
    |> websocket.on_close(fn (event: Dynamic) { Nil })
    |> websocket.on_error(fn (event: Dynamic) { Nil })
    |> websocket.on_text(fn (content: String, event) { io.println(content) })
    |> websocket.on_bytes(fn (content: BitArray, event) { echo content })
    |> websocket.open
  let assert Ok(_) = websocket.send(ws, "Hello world!")
  let assert Ok(_) = websocket.send_bytes(ws, <<"Hello world!">>)
  let assert Ok(_) = websocket.close(ws, code: 1000, reason: "normal")
}
```
