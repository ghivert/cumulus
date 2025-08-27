import gleam/dynamic.{type Dynamic}
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/uri.{type Uri}

pub type WebSocket

/// Builders are used to construct the desired WebSocket. Use `new`, `protocols`
/// and `open` to create your `Builder` and opening your `WebSocket`.
pub opaque type Builder {
  Builder(
    uri: Uri,
    protocols: List(String),
    on_open: Option(fn(Dynamic) -> Nil),
    on_close: Option(fn(Dynamic) -> Nil),
    on_error: Option(fn(Dynamic) -> Nil),
    on_text: Option(fn(String, Dynamic) -> Nil),
    on_bytes: Option(fn(BitArray, Dynamic) -> Nil),
  )
}

/// Return the number of bytes of data that have been queued using calls to
/// `send` but not yet transmitted to the network. This value resets to zero
/// once all queued data has been sent. This value does not reset to zero when
/// the connection is closed; if you keep calling `send`,
/// this will continue to climb.
@external(javascript, "./stratocumulus.ffi.mjs", "bufferedAmount")
pub fn buffered_amount(websocket: WebSocket) -> Int

/// Return the extensions selected by the server. This is currently only the
/// empty string or a list of extensions as negotiated by the connection.
@external(javascript, "./stratocumulus.ffi.mjs", "extensions")
pub fn extensions(websocket: WebSocket) -> String

/// Return the name of the sub-protocol the server selected; this will be
/// one of the strings specified in the protocols parameter when creating the
/// WebSocket, or the empty string if no connection is established.
@external(javascript, "./stratocumulus.ffi.mjs", "protocol")
pub fn protocol(websocket: WebSocket) -> String

/// State of the WebSocket. A WebSocket is _always_ in one of those four states.
pub type ReadyState {
  /// Socket has been created. The connection is not yet open.
  Connecting
  /// The connection is open and ready to communicate.
  Open
  /// The connection is in the process of closing.
  Closing
  /// The connection is closed or couldn't be opened.
  Closed
}

/// Return the current state of the WebSocket connection.
@external(javascript, "./stratocumulus.ffi.mjs", "readyState")
pub fn ready_state(websocket: WebSocket) -> ReadyState

/// Return the absolute URI of the WebSocket as resolved by the WebSocket itself.
pub fn uri(websocket: WebSocket) -> Uri {
  let url = url(websocket)
  let assert Ok(uri) = uri.parse(url)
  uri
}

/// Init a new WebSocket Builder. A Builder is the equivalent of a blueprint,
/// on which we can spawn an infinite amount of WebSockets.
///
/// ```gleam
/// let assert Ok(endpoint) = uri.parse("...")
/// let assert Ok(ws) = stratocumulus.new(endpoint) |> stratocumulus.open
/// let assert Ok(_) = stratocumulus.send(ws, "Hello world!")
/// ```
pub fn new(uri: Uri) -> Builder {
  Builder(
    uri:,
    protocols: [],
    on_open: None,
    on_close: None,
    on_error: None,
    on_text: None,
    on_bytes: None,
  )
}

/// A single string or an array of strings representing the
/// [sub-protocol(s)](https://developer.mozilla.org/docs/Web/API/WebSockets_API/Writing_WebSocket_servers#subprotocols)
/// that the client would like to use, in order of preference. If it is omitted,
/// an empty list is used by default, i.e., `[]`.
///
/// A single server can implement multiple WebSocket sub-protocols, and handle
/// different types of interactions depending on the specified value. Note
/// however that only one sub-protocol can be selected per connection.
///
/// The allowed values are those that can be specified in the
/// [`Sec-WebSocket-Protocol`](https://developer.mozilla.org/docs/Web/HTTP/Reference/Headers/Sec-WebSocket-Protocol)
/// HTTP header. These are values selected from the
/// [IANA WebSocket Subprotocol Name Registry](https://www.iana.org/assignments/websocket/websocket.xml#subprotocol-name),
/// such as `soap`, `wamp`, `ship` and so on, or may be a custom name jointly
/// understood by the client and the server.
///
/// [MDN Reference](https://developer.mozilla.org/en-US/docs/Web/API/WebSocket/WebSocket#protocols)
///
/// ```gleam
/// let assert Ok(endpoint) = uri.parse("...")
/// stratocumulus.new(endpoint)
/// |> stratocumulus.protocols(["soap"])
/// |> stratocumulus.open
/// ```
pub fn protocols(builder: Builder, protocols: List(String)) -> Builder {
  Builder(..builder, protocols:)
}

/// Create & open the WebSocket from its Builder. This is the equivalent to
/// creating the WebSocket with `new WebSocket` in JavaScript.
///
/// ```gleam
/// let assert Ok(endpoint) = uri.parse("...")
/// stratocumulus.new(endpoint)
/// |> stratocumulus.protocols(["soap"])
/// |> stratocumulus.open
/// ```
pub fn open(builder: Builder) -> Result(WebSocket, OpenError) {
  let endpoint = uri.to_string(builder.uri)
  create(endpoint, builder.protocols)
  |> maybe(builder.on_open, fn(ws, l) { add_event_listener(ws, "open", l) })
  |> maybe(builder.on_close, fn(ws, l) { add_event_listener(ws, "close", l) })
  |> maybe(builder.on_error, fn(ws, l) { add_event_listener(ws, "error", l) })
  |> maybe(builder.on_text, fn(ws, l) { add_text_listener(ws, l) })
  |> maybe(builder.on_bytes, fn(ws, l) { add_bit_array_listener(ws, l) })
}

pub type OpenError {
  /// Happens when
  /// - `uri` has a scheme other than ws, wss, http, or https
  /// - `uri` has a [fragment](https://developer.mozilla.org/docs/Web/URI/Reference/Fragment)
  /// - any of the values in `protocols` occur more than once, or otherwise fail
  ///   to match the requirements for elements that comprise the value of
  ///   [`Sec-WebSocket-Protocol`](https://developer.mozilla.org/docs/Web/HTTP/Guides/Protocol_upgrade_mechanism#sec-websocket-protocol) fields
  ///   as defined by the WebSocket Protocol specification
  OpenSyntaxError
}

/// Close an opened WebSocket.
///
/// ```gleam
/// let assert Ok(endpoint) = uri.parse("...")
/// let assert Ok(ws) = stratocumulus.new(endpoint) |> stratocumulus.open
/// let assert Ok(_) = stratocumulus.close(ws, code: 1000, reason: "normal")
/// ```
@external(javascript, "./stratocumulus.ffi.mjs", "close")
pub fn close(
  websocket: WebSocket,
  code code: Int,
  reason reason: String,
) -> Result(Nil, CloseError)

/// Possible errors that can be received after calling [`close`](#close).
pub type CloseError {
  /// `code` is neither an integer equal to `1000`
  /// nor an integer in the range `3000` – `4999`.
  InvalidAccessError
  /// The UTF-8-encoded `reason` value is longer than 123 bytes.
  ReasonSyntaxError
}

/// Send a text frame on the WebSocket.
/// The WebSocket will be returned on success.
/// An error will be returned in case the WebSocket state is `Connecting`.
///
/// ```gleam
/// let assert Ok(endpoint) = uri.parse("...")
/// let assert Ok(ws) = stratocumulus.new(endpoint) |> stratocumulus.open
/// let assert Ok(_) = stratocumulus.send(ws, "Hello world!")
/// ```
@external(javascript, "./stratocumulus.ffi.mjs", "send")
pub fn send(ws: WebSocket, content: String) -> Result(WebSocket, SendError)

/// Possible errors that can be received after calling [`send`](#send)
/// or [`send_bytes`](#send_bytes).
pub type SendError {
  /// Thrown if [`ready_state`](#ready_state) is `Connecting`.
  InvalidStateError
}

/// Send a binary frame on the WebSocket.
/// The WebSocket will be returned on success.
/// An error will be returned in case the WebSocket state is `Connecting`.
///
/// ```gleam
/// let assert Ok(endpoint) = uri.parse("...")
/// let assert Ok(ws) = stratocumulus.new(endpoint) |> stratocumulus.open
/// let assert Ok(_) = stratocumulus.send(ws, <<"Hello world!">>)
/// ```
@external(javascript, "./stratocumulus.ffi.mjs", "send")
pub fn send_bytes(
  websocket: WebSocket,
  content: BitArray,
) -> Result(WebSocket, SendError)

/// Subscribe to the `"open"` event. `"open"` will be emitted after the Socket
/// has been opened with the remote server. The argument received is a generic
/// [`Event`](https://developer.mozilla.org/docs/Web/API/Event).
/// `on_open` returns the original WebSocket to continue chaining commands on
/// the WebSocket.
///
/// ```gleam
/// let assert Ok(endpoint) = uri.parse("...")
/// stratocumulus.new(endpoint)
/// |> stratocumulus.on_open(fn (data) { Nil })
/// |> stratocumulus.on_close(fn (data) { Nil })
/// |> stratocumulus.on_error(fn (data) { Nil })
/// ```
pub fn on_open(builder: Builder, on_open: fn(Dynamic) -> Nil) -> Builder {
  let on_open = Some(on_open)
  Builder(..builder, on_open:)
}

/// Subscribe to the `"close"` event. `"close"` will be emitted after the Socket
/// has been closed with the remote server. The argument received is a
/// [`CloseEvent`](https://developer.mozilla.org/docs/Web/API/CloseEvent).
/// `on_close` returns the original WebSocket to continue chaining commands on
/// the WebSocket.
///
/// ```gleam
/// let assert Ok(endpoint) = uri.parse("...")
/// stratocumulus.new(endpoint)
/// |> stratocumulus.on_open(fn (data) { Nil })
/// |> stratocumulus.on_close(fn (data) { Nil })
/// |> stratocumulus.on_error(fn (data) { Nil })
/// ```
pub fn on_close(builder: Builder, on_close: fn(Dynamic) -> Nil) -> Builder {
  let on_close = Some(on_close)
  Builder(..builder, on_close:)
}

/// Subscribe to the `"error"` event. `"error"` will be emitted when an error
/// has occur, like some data that could not be sent. The argument received is a
/// generic [`Event`](https://developer.mozilla.org/docs/Web/API/Event).
/// `on_error` returns the original WebSocket to continue chaining commands on
/// the WebSocket.
///
/// ```gleam
/// let assert Ok(endpoint) = uri.parse("...")
/// stratocumulus.new(endpoint)
/// |> stratocumulus.on_open(fn (data) { Nil })
/// |> stratocumulus.on_close(fn (data) { Nil })
/// |> stratocumulus.on_error(fn (data) { Nil })
/// ```
pub fn on_error(builder: Builder, on_error: fn(Dynamic) -> Nil) -> Builder {
  let on_error = Some(on_error)
  Builder(..builder, on_error:)
}

/// Subscribe to text messages received. Everytime the WebSocket receives
/// a textual message, an event is received with the text as content.
/// The second argument is the event itself, in case it is needed for other usages.
///
/// ```gleam
/// let assert Ok(endpoint) = uri.parse("...")
/// stratocumulus.new(endpoint)
/// |> stratocumulus.on_open(fn (data) { Nil })
/// |> stratocumulus.on_close(fn (data) { Nil })
/// |> stratocumulus.on_error(fn (data) { Nil })
/// |> stratocumulus.on_text(fn (content: String, event) { Nil })
/// ```
pub fn on_text(builder: Builder, on_text: fn(String, Dynamic) -> Nil) -> Builder {
  let on_text = Some(on_text)
  Builder(..builder, on_text:)
}

/// Subscribe to bytes messages received. Everytime the WebSocket receives
/// a binary message, an event is received with the bytes as content.
/// The second argument is the event itself, in case it is needed for other usages.
///
/// ```gleam
/// let assert Ok(endpoint) = uri.parse("...")
/// stratocumulus.new(endpoint)
/// |> stratocumulus.on_open(fn (data) { Nil })
/// |> stratocumulus.on_close(fn (data) { Nil })
/// |> stratocumulus.on_error(fn (data) { Nil })
/// |> stratocumulus.on_bytes(fn (content: BitArray, event) { Nil })
/// ```
pub fn on_bytes(
  builder: Builder,
  on_bytes: fn(BitArray, Dynamic) -> Nil,
) -> Builder {
  let on_bytes = Some(on_bytes)
  Builder(..builder, on_bytes:)
}

// Internal

@external(javascript, "./stratocumulus.ffi.mjs", "addStringMessageListener")
fn add_text_listener(
  websocket: WebSocket,
  handler: fn(String, Dynamic) -> Nil,
) -> WebSocket

@external(javascript, "./stratocumulus.ffi.mjs", "addBitArrayMessageListener")
fn add_bit_array_listener(
  websocket: WebSocket,
  handler: fn(BitArray, Dynamic) -> Nil,
) -> WebSocket

@external(javascript, "./stratocumulus.ffi.mjs", "addEventListener")
fn add_event_listener(
  websocket: WebSocket,
  event: String,
  handler: fn(Dynamic) -> Nil,
) -> WebSocket

@external(javascript, "./stratocumulus.ffi.mjs", "create")
fn create(url: String, protocols: List(String)) -> Result(WebSocket, OpenError)

@external(javascript, "./stratocumulus.ffi.mjs", "url")
fn url(websocket: WebSocket) -> String

fn maybe(
  websocket: Result(WebSocket, OpenError),
  data: Option(a),
  mapper: fn(WebSocket, a) -> WebSocket,
) -> Result(WebSocket, OpenError) {
  use websocket <- result.map(websocket)
  case data {
    None -> websocket
    Some(data) -> mapper(websocket, data)
  }
}
