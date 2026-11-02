# HTTP stack fingerprinting → likely parser → differential surface

> **Scope & intent.** This is defensive/research reconnaissance for *our own* differential
> harness: given a deployment, infer which HTTP implementations are in the request path so
> we know *which parsers to put in the test matrix* and which library pairs plausibly
> disagree. Same reasoning a blue team uses to inventory its own edge, or to reproduce a
> published CVE against a lab copy. All exploitation belongs in a lab you own; this doc
> stops at "which libraries are probably here, and do their known differentials line up."
> CVE/write-up facts are from memory as of ~2025 — verify against NVD/vendor before relying.

## 0. Why this is the bridge between our three strands
- **parser-differentials**: a differential only matters where two *specific* parsers meet.
  The common topology is `[client] → [CDN/WAF] → [reverse proxy / API gateway] → [app server]`.
  Each arrow is a potential front-end/back-end disagreement (the desync shape).
- **upsolve**: once we know "this host runs nginx 1.18 → gunicorn 20", we know exactly which
  version bumps changed framing behavior — the sparse-change prior over *parser* symbols.
- **deformalize**: each known desync maps to the RFC sentence the two sides read differently.

## 1. Recent HTTP desync / framing CVEs (last few years)
| Year | Component (parser) | Class | CVE / source |
|---|---|---|---|
| 2019 | many (front/back pairs) | CL.TE / TE.CL rediscovery | Kettle, [Desync Attacks](https://portswigger.net/research/http-desync-attacks-request-smuggling-reborn) |
| 2020–21 | Node **llhttp** | lenient TE, chunk parsing | CVE-2020-8201, -8287, CVE-2021-22959/-22960 |
| 2021 | Apache **mod_proxy** | request splitting via crafted URI | [CVE-2021-40438](https://nvd.nist.gov/vuln/detail/CVE-2021-40438) (SSRF), related 2021-33193 (h2) |
| 2021 | HAProxy | integer/length handling | CVE-2021-40346 (TE smuggling) |
| 2021 | HTTP/2 → HTTP/1 downgrade | pseudo-header → request line | Kettle, [HTTP/2: Sequel](https://portswigger.net/research/http2) |
| 2022 | F5 BIG-IP | auth bypass on mgmt (iControl) | [CVE-2022-1388](https://nvd.nist.gov/vuln/detail/CVE-2022-1388) (not pure desync but edge-parser trust) |
| 2022 | browser-powered | client-side desync | Kettle, [Browser-Powered Desync](https://portswigger.net/research/browser-powered-desync-attacks) |
| 2023 | Apache **mod_proxy** | request splitting | [CVE-2023-25690](https://nvd.nist.gov/vuln/detail/CVE-2023-25690) (RewriteRule/ProxyPass) |
| 2023 | HTTP/2 | stream reset flood | [CVE-2023-44487](https://nvd.nist.gov/vuln/detail/CVE-2023-44487) (Rapid Reset; framing-adjacent DoS) |
| 2023 | Gunicorn / others | TE handling, chunk extensions | HTTP Garden-era CVEs |
| 2024 | Apache httpd | content/handler/path confusion | [Confusion Attacks](https://blog.orange.tw/posts/2024-08-confusion-attacks-en/) |
| 2024 | Apache **Traffic Server** | multiple framing | [CVE-2024-27316](https://nvd.nist.gov/vuln/detail/CVE-2024-27316) (HTTP/2 CONTINUATION flood era) |
| 2025 | front/back pairs broadly | "the attack isn't dead" | Kettle, [HTTP/1.1 Must Die](https://portswigger.net/research/http1-must-die) |
| 2025 | SMTP (adjacent genre) | end-of-data smuggling | CVE-2023-51764 (for the pattern) |

Public tooling that encodes the probe logic (study for *what signals* they read, not to run
against others): [smuggler](https://github.com/defparam/smuggler),
[h2csmuggler](https://github.com/BishopFox/h2csmuggler), and the
[HTTP Garden](https://github.com/narfindustries/http-garden) corpus/adapters.

## 2. Common stacks & where the parsers sit
Typical request path and the parser at each hop:

```
client ─ TLS ─▶ CDN/WAF ─▶ reverse proxy / API gateway ─▶ app server ─▶ app
                 │              │                            │
             (parser A)     (parser B)                   (parser C)
```
Any A/B or B/C pair with different leniency is the differential.

### CDN / WAF (edge, parser A)
| Vendor | Underlying engine | Tells |
|---|---|---|
| Cloudflare | custom (Rust/`cf-*`) | `server: cloudflare`, `cf-ray`, `cf-cache-status` |
| Fastly | Varnish-derived | `x-served-by`, `x-cache`, `via: ... varnish`, `fastly-*` |
| Akamai | custom | `x-akamai-*`, `akamai-grn`, `server: AkamaiGHost` |
| AWS CloudFront | custom | `x-amz-cf-id`, `x-amz-cf-pop`, `via: ... cloudfront` |
| Azure Front Door | custom | `x-azure-ref`, `x-cache` |
| nginx-based WAFs | nginx + ModSecurity | `server: nginx`, odd 400/403 bodies |

### Reverse proxy / API gateway (parser B)
| Gateway | HTTP engine (the parser) | Tells |
|---|---|---|
| nginx / nginx-plus | `ngx_http_parse.c` | `server: nginx`, 400 page HTML, `\r\n` strictness |
| Kong / OpenResty | nginx + LuaJIT | `server: openresty`, `via: kong/x.y`, `x-kong-*` |
| Envoy (Istio, Contour, many meshes) | BalsaParser / llhttp | `server: envoy`, `x-envoy-upstream-service-time` |
| HAProxy | `src/h1.c` (strict) | `server:` often stripped; distinctive 400; cookie `SERVERID` |
| Traefik | Go `net/http` | `server:` usually absent; behaves like Go |
| AWS ALB / API Gateway | custom (not open) | `x-amzn-trace-id`, `x-amzn-requestid`, `server: awselb/2.0` |
| Apache httpd + mod_proxy | `server/protocol.c` | `server: Apache/2.4.x (os)`, ETag format |
| Apache Traffic Server | own | `server: ATS`, `via: ... ApacheTrafficServer` |
| Caddy | Go `net/http` | `server: Caddy` |
| F5 BIG-IP | TMM proxy | `server: BigIP`, `x-waf-*`, `BIGipServer` cookie |

### App server (parser C) — inferred from framework/runtime tells
| Runtime | App servers (parser) | Tells |
|---|---|---|
| Node.js | Node `http` (llhttp), undici, Fastify, Express behind it | `x-powered-by: Express`, ETag `W/"..."` style, `connection: keep-alive` quirks |
| Python | gunicorn, uvicorn, waitress, Tornado, Twisted | `server: gunicorn/20.1.0`, `server: Werkzeug/x Python/3.y` (dev), `uvicorn` |
| Ruby | puma, unicorn, webrick, passenger | `server: puma 6.x`, `x-runtime`, `_session_id` cookie, `x-powered-by: Phusion Passenger` |
| Java/JVM | Tomcat, Jetty, Netty, Undertow, Spring Boot | `JSESSIONID` cookie, `server: Apache-Coyote/1.1`, `x-application-context` |
| Go | `net/http` (Caddy/Traefik/gin/echo) | minimal/absent `server`, date header format, HTTP/2 push defaults |
| .NET | Kestrel, IIS/http.sys | `server: Kestrel`, `server: Microsoft-IIS/10.0`, `x-aspnet-version`, `.AspNetCore` cookie |
| PHP | php-fpm behind nginx/Apache | `x-powered-by: PHP/8.x`, `PHPSESSID` cookie |

## 3. From client-visible signal → best-guess parser
What a plain client sees in a *response* (no attack, just a normal request) and what it implies:

1. **`Server` header** — most direct, but often stripped at the edge or set to the CDN. When
   present on an error page but not success (or vice-versa), you're seeing *two* hops.
2. **`Via` / `X-Cache` / `X-Served-By`** — proxy chain disclosure; names the intermediary.
3. **Cookie names** — `JSESSIONID`→Java, `PHPSESSID`→PHP, `_<app>_session`→Rails/puma,
   `.AspNetCore.*`→Kestrel, `connect.sid`→Express, `BIGipServer*`→F5.
4. **`X-Powered-By` / `X-AspNet-Version` / `X-Runtime` / `X-Application-Context`** — runtime leak.
5. **Error-page fingerprints** — nginx's `<center>nginx</center>` 400/404; Apache's styled
   error; Jetty/Tomcat stack-trace format; Go's plain `400 Bad Request`; Werkzeug debugger.
6. **Header ordering & casing** — each server emits response headers in a characteristic
   order and case (`Date`/`Content-Type` position, `ETag` vs `Etag`). This is the basis of
   passive fingerprinting (JARM-for-HTTP style, `httpfp`, Salesforce's work).
7. **Date header format & keep-alive/timeout behavior** — Go vs C servers differ.
8. **HTTP/2 & ALPN** — `h2` offered? SETTINGS values, header-table size, max concurrent
   streams differ by server; HTTP/2 → HTTP/1 downgrade at the edge is itself the Kettle-2021
   surface.
9. **Which malformed-but-legal inputs get a 400 vs 200** — *this is the differential signal
   itself*: a strict front end (HAProxy, Go, h11) rejects what a lenient back end accepts.
   In our harness we don't need a live target for this — we run the candidate parsers
   locally against the same bytes.

**Mapping heuristic (what the harness should encode):**
`edge_vendor × gateway × runtime  ⇒  {parser_A, parser_B, parser_C}` with a confidence,
then look up each pair in a **known-divergence table** (CL/TE precedence, obs-fold, bare-LF,
chunk-ext, header-name validation). Output: "this topology has a known A/B divergence on
*bare-LF line endings* — add llhttp(lenient) vs HAProxy(strict) to the matrix." The
divergence table is just `BACKGROUND.md §2` + `HTTP.md §1` turned into rows.

## 4. A small data model (proposed `data/stacks.csv`)
```
tier,product,engine,parser_file,leniency,tells
edge,Cloudflare,custom-rust,,strict?,cf-ray;server:cloudflare
gateway,Kong,openresty,ngx_http_parse.c,medium,server:openresty;x-kong-*
gateway,Envoy,balsa-or-llhttp,,configurable,server:envoy;x-envoy-upstream-service-time
app,gunicorn,python,gunicorn/http/parser.py,lenient,server:gunicorn
app,Kestrel,dotnet,,strict,server:Kestrel;.AspNetCore cookie
...
```
Join this with `data/libraries.enriched.*` on `engine`/`parser_file` to carry the
size/age/velocity/quality proxies through to each deployment guess. Then the demo can say:
"you're talking to Cloudflare→Kong→gunicorn; the Kong(nginx)↔gunicorn pair is a known
CL/TE divergence; here are the 3 inputs on which our local copies of those two parsers
disagree, and the RFC 9112 sentence each one leaned on."

## 5. Open questions / to verify
- Confirm the 2024–2025 Apache/ATS CVE IDs and exact components against NVD.
- Is passive header-order fingerprinting reliable enough to seed the stack guess, or do we
  need active (benign) probes? Prefer passive for the demo.
- Which gateways default to HTTP/2 upstream (changes parser C from H1 to H2 translation)?
- Build `data/stacks.csv` + a join script; this is a good follow-up task.
