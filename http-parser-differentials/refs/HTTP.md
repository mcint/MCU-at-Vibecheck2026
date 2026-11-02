# HTTP/1.1 parsers — anatomy, extraction, and who's not separable

> Goal: run the *parser portion* of many HTTP implementations against the same bytes and
> diff the results. That needs (a) a clear definition of "the parser portion", (b) per-library
> notes on whether it can be called in isolation, and (c) heuristics for triaging the long
> tail of widely-used libraries we haven't looked at. All library facts below are from
> memory of the codebases as of ~2025 and marked ~ where unsure; verify against source
> before relying on them.

## 1. What "the parser" is — stages of HTTP/1.1 request processing
Differentials can occur at any stage; most CVEs are at **framing** (stage 4).

| # | Stage | Input → Output | Where differentials live |
|---|---|---|---|
| 1 | **Request line** | bytes → (method, target, version) | whitespace variants (`\t`, multiple SP), absolute-form vs origin-form target, `HTTP/1.0` vs `1.1` vs `1.2`, bare `\n` line endings, leading CRLFs |
| 2 | **Header fields** | bytes → list of (name, value) | obs-fold (leading SP/HTAB continuation), whitespace around `:`, NUL / CR / high bytes in values, duplicate headers (combine? first? last?), name case, invalid chars accepted |
| 3 | **Header semantics** | list → typed values | `Content-Length` with `+`, leading zeros, multiple CLs (same/different), `Transfer-Encoding: chunked` vs `xchunked` vs `chunked, identity` vs ` chunked`, `Connection` tokens, `Host` presence/validity |
| 4 | **Framing / body length** | typed headers → body boundary | **CL vs TE precedence** (RFC 9112 §6.3), chunk-size parsing (hex prefix, `;ext`, size overflow, `0x`), chunk terminators (`\n` vs `\r\n`), trailers, premature EOF, body on GET/HEAD |
| 5 | **Message boundary / pipelining** | body end → next request start | leftover bytes after body, CRLF between messages, `Connection: close` honored? |
| 6 | **Target parsing** | request-target → path, query | percent-decoding timing, `..` normalization, `;` params, `#` fragment, backslash, double slash — the Orange Tsai 2018 class |
| 7 | **Upgrade / version switching** | HTTP/2 ↔ HTTP/1.1 translation | H2 pseudo-headers → H1 line (Kettle 2021); `:method` with spaces; CRLF in H2 header values |

**The parser portion** for our purposes = stages 1–5 with the output being a *structured
message* `{method, target, version, headers:[(name,value)], body:bytes, rest:bytes}` or an
*error* `{stage, reason}`. Stage 6 is a second parser (URL); stage 7 is translation.
Differential = two implementations produce non-equal structured messages, or one errors
and the other doesn't, on the same bytes.

**Canonical output format** (what every adapter should emit, one JSON line per input):
```json
{"impl":"llhttp@9.2","input":"<sha256>","ok":true,
 "method":"GET","target":"/","version":"1.1",
 "headers":[["content-length","5"],["transfer-encoding","chunked"]],
 "body_len":5,"body_sha":"...","rest_len":0,
 "err":null}
```
Normalize header *names* to lowercase in the adapter, keep values byte-exact, keep order.
Record `rest_len` — bytes the parser did not consume — because that is where the second
smuggled request lives.

## 2. Per-library: is the parser separable?

**Separability scale:** `S` standalone library (parser is the product) · `C` callable in
isolation with modest glue (one file/class, no server loop) · `E` entangled (parser reads
from a connection object / arena / event loop; need to stub) · `X` not practically
separable (parsing interleaved with dispatch, or in a different process).

### C / C++
| Library | Sep. | Where the parser is | Notes |
|---|---|---|---|
| **llhttp** | S | the whole repo; `llhttp_execute()` with callbacks | Node ≥12. Generated from TypeScript via llparse. Has `lenient_*` flags — each one is a documented differential. Bindings: `httptools` (py), `undici` (wasm), `aiohttp` (vendored). |
| **picohttpparser** | S | `phr_parse_request()` | H2O's. Headers only — *no framing*; you implement CL/TE yourself. Good control: a parser that cannot have stage-4 bugs because it doesn't do stage 4. |
| **http-parser** (joyent, legacy) | S | `http_parser_execute()` | Deprecated; still vendored in old Node, some Python packages. Ancestor of llhttp — diff them. |
| **nginx** | E | `src/http/ngx_http_parse.c` (`ngx_http_parse_request_line`, `_header_line`, `_chunked`) | Pure state machines over `ngx_buf_t`, but take `ngx_http_request_t*`. Stub the request struct → callable. Body framing in `ngx_http_request_body.c` is more entangled. |
| **Apache httpd** | E/X | `server/protocol.c` (`read_request_line`, `ap_get_mime_headers_core`), chunked in `modules/http/http_filters.c` | Needs pools + bucket brigades; framing is an *input filter*. Practically: run httpd and observe (HTTP Garden approach). |
| **HAProxy** | E | `src/h1.c` (`h1_headers_to_hdr_list`), `src/h1_htx.c` | Converts H1 to HTX. `h1.c` is relatively pure; needs `struct h1m`. HAProxy is *strict* by design — good reference impl. |
| **H2O** | S/E | uses picohttpparser; framing in `lib/http1.c` | |
| **libcurl** | E | `lib/http.c`, `lib/http_chunks.c` | *Client-side* response parser; different ambiguities (response framing, `HTTP/1.0` no-CL = read to EOF). |
| **lighttpd** ~ | E | `src/http_header.c`, `src/request.c` | |
| **Envoy** | E | wraps **http-parser**/llhttp via `BalsaParser` (Google's) or `LegacyHttpParserImpl` | Two parsers selectable at runtime — a built-in differential. |

### Rust
| Library | Sep. | Where | Notes |
|---|---|---|---|
| **httparse** | S | `Request::parse()` | Headers only; no framing. SIMD paths — differential vs scalar path is itself a question. |
| **hyper** | C | `src/proto/h1/role.rs` (`Server::parse`), `decode.rs` (chunked) | Uses httparse then adds framing. Framing logic is callable with a `BytesMut`. |
| **actix-http** ~ | C | `src/h1/decoder.rs` | own framing on top of httparse |
| **h2** | S | HPACK + frames | stage 7 differential partner |

### Go
| Library | Sep. | Where | Notes |
|---|---|---|---|
| **net/http** | C | `net/http/request.go` `ReadRequest(*bufio.Reader)`, `net/textproto` for headers, `net/http/internal/chunked.go` | `ReadRequest` is exported and takes a reader — directly callable. Go made several deliberate choices (reject bare `\n`? ~, reject CL+TE since 1.x) — good *strict* reference. `chunked.go` is `internal` but copyable. |
| **fasthttp** | C | `request.go` `Request.Read()` | Known-lenient; explicitly trades correctness for speed. High value target. |

### Python
| Library | Sep. | Where | Notes |
|---|---|---|---|
| **h11** | S | `h11.Connection.receive_data()` / `next_event()` | Sans-IO, strict, well-specified. **Best oracle candidate**; its README enumerates the RFC decisions it made. |
| **httptools** | S | llhttp binding | |
| **gunicorn** | C | `gunicorn/http/parser.py`, `message.py` (`Request`), `body.py` (`ChunkedReader`) | Pure Python; takes a socket-like with `recv`; stub with BytesIO-ish. Many Garden CVEs 2023–24 — chunk extension, TE handling. |
| **tornado** | E | `tornado/http1connection.py` + `httputil.parse_headers` / `HTTPHeaders.parse` | Headers callable; framing in `HTTP1Connection._read_message` tied to IOStream. |
| **aiohttp** | C | `aiohttp/http_parser.py` (`HttpRequestParser`, `HttpPayloadParser`) + C accelerated `_http_parser.pyx` (llhttp) | **Two parsers in one package** (pure vs C). Pure-Python path is a differential partner for llhttp. |
| **uvicorn** | — | delegates to httptools or h11 | runtime-selectable → built-in differential |
| **Twisted** ~ | E | `twisted/web/http.py` `HTTPChannel.lineReceived` | line-based, classic |
| **http.server / http.client** | C | `http.client.parse_headers`, `email.parser` (!) | stdlib parses HTTP headers with the **email** header parser. RFC 5322 vs 9110 semantics. Stage-2 differentials guaranteed. |
| **waitress** ~ | C | `waitress/parser.py` | pure Python, own state machine |

### JavaScript / Node
| Library | Sep. | Where | Notes |
|---|---|---|---|
| **Node `http`** | — | llhttp via `process.binding('http_parser')` | `--insecure-http-parser` flag flips lenient mode: built-in differential |
| **undici** | — | llhttp compiled to wasm | client |
| **Deno / Bun** ~ | E | Deno: hyper; Bun: picohttpparser (+own framing) | Bun's own framing is a fresh codebase → likely rich |

### Ruby
| Library | Sep. | Where | Notes |
|---|---|---|---|
| **puma** | S/C | `ext/puma_http11/http11_parser.rl` (Ragel) → `Puma::HttpParser` | Ragel grammar = *declarative* — closest thing to a spec. Headers only; framing in `lib/puma/client.rb` (`setup_chunked_body`, `read_body`). Garden CVEs 2023–24 in chunked. |
| **webrick** | C | `WEBrick::HTTPRequest#parse(socket)` | pure Ruby; historic smuggling CVEs |
| **unicorn** ~ | S | `ext/unicorn_http/unicorn_http.rl` (Ragel, forked from Mongrel) | Same ancestry as puma — a sibling-fork differential |
| **Net::HTTP** | C | `net/http/response.rb` (client) | |

### Java
| Library | Sep. | Where | Notes |
|---|---|---|---|
| **Netty** | C | `HttpObjectDecoder` / `HttpRequestDecoder` (`codec-http`) | Feed an `EmbeddedChannel` bytes, read decoded objects. Clean. Config flags: `allowDuplicateContentLengths`, `validateHeaders`, `allowPartialChunks` — each a differential knob. |
| **Tomcat** | E | `org.apache.coyote.http11.Http11InputBuffer`, `ChunkedInputFilter`, `IdentityInputFilter` | needs a `Request` + wrapper; stubbable. Tomcat rejects a lot (RFC-strict since 8.5/9). |
| **Jetty** | C | `org.eclipse.jetty.http.HttpParser` with `HttpParser.RequestHandler` callbacks | Designed to be driven with `ByteBuffer`s. Has `Compliance` modes (`RFC7230`, `LEGACY`, `RFC2616`) — **explicit lenience lattice**. |
| **Undertow** ~ | C | `io.undertow.server.protocol.http.HttpRequestParser` (generated) | |
| **JDK `com.sun.net.httpserver`** ~ | E | `sun.net.httpserver.Request` | |

### Others worth a row
Caddy (Go net/http), Traefik (Go net/http) — same parser, differ in *stage 6/7*;
Varnish (`cache/cache_http1_proto.c`, strict); Squid; ATS; IIS/http.sys (X, closed);
CPython `wsgiref` (uses `http.server`); Erlang `cowboy` (`cow_http`), Elixir Bandit
(own parser ~ ); PHP-FPM FastCGI (not HTTP); Kong/OpenResty (nginx).

## 3. Heuristics for triaging libraries you haven't opened

### Features that predict *separable* (and therefore testable)
- `sans-io` / "no I/O" in README (h11, httparse, llhttp, Netty codecs).
- A function taking `(buf, len)` or `bytes` and returning a struct/offset, with no socket
  argument. grep: `parse_request(`, `_execute(`, `ReadRequest(`, `receive_data(`.
- Ragel (`*.rl`), re2c, or generated-state-machine files: the grammar exists as data.
- A `lenient` / `strict` / `compliance` flag: the authors already know the differentials.
- Published fuzz harness (`fuzz/`, `oss-fuzz` integration): entry point already isolated.
- Headers-only scope (picohttpparser, httparse): stage 4 is *your* job — means the
  consuming framework's framing code is where to look instead.

### Anti-features that predict *entangled* (and high impact)
- Parser functions take a `request`/`connection`/`stream` object (nginx, Apache, Tornado).
- Framing implemented as a *filter/middleware* in a pipeline (Apache input filters).
- Parsing spread over `lineReceived` / `on_data` callbacks on an event loop (Twisted,
  classic Node userland parsers).
- Header parsing delegated to a non-HTTP parser (Python `email.parser`; some MIME libs).
- Two parsers in one product selectable by config/flag (Envoy, uvicorn, aiohttp, Node
  `--insecure-http-parser`): every flag value is a separate implementation to test.
- "Fast" in the name or README (fasthttp, picohttpparser, simdjson-style): speed claims
  correlate with hand-rolled scanning and skipped validation.
- Forks with shared ancestry (puma/unicorn/mongrel; llhttp/http-parser; Caddy/Traefik via
  net/http): differentials between siblings are *regressions or fixes*, each a story.

### Impact / "widely used but not ready" proxies (from `data/libraries.enriched.*`)
- `libio_dependents` high, `gh_commits_90d` low → widely used, under-maintained.
- Framework (not parser) with its own framing code and no fuzz dir → gunicorn-class.
- Deployed at the *edge* (reverse proxy, CDN, LB) → front-end/back-end pair → smuggling
  surface. Rank: proxies > app servers > clients.
- Written before RFC 7230 (2014) and still alive → implements RFC 2616 semantics
  (e.g. CL+TE precedence was *unspecified* pre-7230).

## 4. A minimal plan for a differential harness (if we do it)
1. **Corpus**: start from HTTP Garden's and T-Reqs' seed inputs, plus a hand-written set
   covering the stage 1–5 table (≈60 cases). Store as `data/http-corpus/*.bin` + a
   manifest with the RFC sentence each case targets — *that manifest is the deformalize
   bridge.*
2. **Adapters**: one per separable library, each emitting the canonical JSON line above.
   Fastest set: h11, httparse+hyper, llhttp (via httptools), Go `net/http.ReadRequest`,
   Netty `EmbeddedChannel`, puma `HttpParser`, picohttpparser, gunicorn. Eight impls,
   six languages, an afternoon.
3. **Diff**: group by input, report inputs where the set of outputs has >1 distinct
   element; classify by stage.
4. **Lean**: a reference parser for the stage 1–5 grammar (RFC 9112 ABNF, ~100 lines of
   ABNF) with the framing rule as a theorem: `frame (headers) = some n ∨ error`. Run it
   as the ninth adapter. Then for each differential, which RFC sentence decides it, and
   does the Lean version encode that sentence? If the RFC is ambiguous, *that's the hinge
   point*: the Lean parser had to pick, and the ABNF didn't force the pick.
5. **Demo**: the same 40 bytes fan out to nine columns; eight lights go green/red
   differently; the Lean column shows the line of RFC text it used to decide.
