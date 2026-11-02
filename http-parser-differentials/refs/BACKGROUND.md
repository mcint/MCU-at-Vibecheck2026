# Parser differentials — background

> Two parsers, one input, two meanings. Security is lost in the gap. This doc: the
> canonical write-ups, the CVEs, who found them and *how*, and the theory. Links were
> checked 2026-10-31 (✓) unless marked ~ (unverified) or † (paywalled/archived).
> Library inventory with metadata is in `LIBRARIES.md` / `data/`.

## 0. Why this interfaces with our ideas
- **deformalize**: a parser differential *is* an ambiguity in a spec (RFC prose) that two
  implementations resolved differently. Hinge words in RFCs ("SHOULD", "may be folded",
  "the last occurrence") are literally where differentials live. The catalogue of hinge
  points has a ready-made ground truth here.
- **upsolve**: parser libraries are the deps where "minor" version bumps silently change
  accepted-language — the sparse-change prior applies to *grammar* symbols.
- **Lean**: a verified parser for one format, plus a differential harness against the
  ecosystem's real parsers, is a demo a grandma gets: "these five programs disagree about
  what this file says; this one is provably right."

## 1. Theory and method
| What | Who | Link |
|---|---|---|
| **LangSec** — "shotgun parsing", parser differentials as a CWE class, recognizers over ad-hoc input handling | Sassaman, Patterson, Bratus, Locasto, Shubina (2011–) | ✓ http://langsec.org/ · ✓ [Security Applications of Formal Language Theory (2011)](https://langsec.org/papers/Sassaman.pdf) · ✓ [The Halting Problems of Network Stack Insecurity, ;login: 2011](https://www.usenix.org/system/files/login/articles/105516-Sassaman.pdf) · ✓ [LangSec CWEs, SecDev 2016](https://langsec.org/papers/langsec-cwes-secdev2016.pdf) |
| **Differential testing** — the general method (run N implementations, diff outputs) | McKeeman, 1998, *Digital Technical Journal* | ~ "Differential Testing for Software" (search title; many mirrors) |
| **Frankencerts** — differential testing of X.509 validation across SSL/TLS libs; synthesizes certs by recombining real ones | Brubaker, Jana, Ray, Khurshid, Shmatikov — IEEE S&P 2014 | ✓ [paper](https://www.cs.cornell.edu/~shmat/shmat_oak14.pdf) |
| **NEZHA** — differential fuzzing guided by *behavioral asymmetry* (δ-diversity), applied to X.509, ELF, PDF, XZ parsers | Petsios, Tang, Stolfo, Keromytis, Jana — IEEE S&P 2017 | ✓ [paper](https://www.cs.columbia.edu/~suman/docs/nezha.pdf) |
| **T-Reqs** — grammar-based differential fuzzing for HTTP request smuggling across servers/proxies | Jabiyev, Sprecher, Onarlioglu, Kirda — CCS 2021 | † ACM · ✓ [code](https://github.com/bahruzjabiyev/t-reqs-http-fuzzer) |
| **FRameShifter** — HTTP/2→HTTP/1.1 downgrade differential fuzzing | Jabiyev et al. — USENIX Sec 2022 | ✓ [paper](https://www.usenix.org/conference/usenixsecurity22/presentation/jabiyev) |
| **HTTP Garden** — differential testing harness for ~30 HTTP servers/proxies; dozens of CVEs; LangSec-flavored | Ben Kallus, Prashant Anantharaman (Dartmouth/Narf) — 2024 | ✓ [repo](https://github.com/narfindustries/http-garden) · ✓ [Dartmouth LangSec](https://www.cs.dartmouth.edu/~sergey/langsec/) |
| **DARPA SafeDocs** — program on parser safety for PDF & co; produced verified/grammar-first parsers and differential tooling | DARPA, 2018–2023 | ✓ [program page](https://www.darpa.mil/program/safe-documents) · ✓ [PolyFile](https://github.com/trailofbits/polyfile) · ✓ [PolyTracker](https://github.com/trailofbits/polytracker) (Trail of Bits) · ✓ [Daedalus](https://github.com/GaloisInc/daedalus) (Galois) |
| **JSONTestSuite** — the test corpus behind "Parsing JSON is a Minefield"; differential results across ~50 parsers | Nicolas Seriot, 2016 | ✓ [article](https://seriot.ch/parsing_json.php) · ✓ [repo](https://github.com/nst/JSONTestSuite) |

**Methods seen, by rough frequency:** (1) hand analysis of RFC ambiguities + manual probes
(Kettle, Orange Tsai, Kaminsky); (2) differential fuzzing with a corpus or grammar
(Frankencerts, NEZHA, T-Reqs, Garden, JSONTestSuite); (3) source review of two codepaths
in the same product (Android master key, ruby-saml); (4) spec-driven test-suite
construction (Seriot). Nobody is doing (5): *derive the differential from a formal spec
by finding under-determined productions*. That's the gap our deformalize angle points at.

## 2. The canon, by format

### X.509 / ASN.1 / TLS
- **Null-prefix / PKI Layer Cake (2009–2010).** CN `www.bank.com\0.evil.com` — CA's ASN.1
  parser sees the whole string, browser's C string stops at NUL. Marlinspike (Black Hat 09)
  and Kaminsky/Patterson/Sassaman (FC 2010) independently. Method: hand analysis of ASN.1
  vs C-string length semantics. CVEs: ✓ [CVE-2009-2408](https://nvd.nist.gov/vuln/detail/CVE-2009-2408) (NSS), CVE-2009-2510 (MS CryptoAPI).
  ✓ [Marlinspike paper](https://www.blackhat.com/presentations/bh-usa-09/MARLINSPIKE/BHUSA09-Marlinspike-DefeatSSL-PAPER1.pdf) · ✓ [PKI Layer Cake](https://ioactive.com/pdfs/PKILayerCake.pdf)
- **Frankencerts (2014)** — 208 discrepancies across OpenSSL, GnuTLS, NSS, CyaSSL, PolarSSL, MatrixSSL. Method: differential fuzzing.

### ZIP / archive formats
- **Android "Master Key" (2013).** Two files with the same name in one ZIP: Java verifier
  checks the first, C installer extracts the second. Bluebox (Jeff Forristal); exploit +
  fix by saurik. Second variant from Android Security Squad (China). Method: source review
  of two codepaths. ✓ [CVE-2013-4787](https://nvd.nist.gov/vuln/detail/CVE-2013-4787) ·
  ✓ [saurik write-up](https://www.saurik.com/id/17) · ✓ [Bluebox (archived)](https://web.archive.org/web/2013id_/https://bluebox.com/technical/uncovering-android-master-key-that-makes-99-of-devices-vulnerable/)
- ZIP is a differential goldmine: central directory vs local headers, concatenated archives,
  zip64 vs legacy fields. Perception Point (2024) on concatenated-ZIP AV evasion (~ link).

### HTTP (request smuggling / desync)
- **Original (2005).** Watchfire: Linhart, Klein, Heled, Orrin — "HTTP Request Smuggling" (~ PDF widely mirrored). CL vs TE disagreement between front-end and back-end.
- **Reborn (2019–2025).** James Kettle / PortSwigger. Method: hand-crafted ambiguity + timing
  oracle + mass scanning. ✓ [Desync Attacks (2019)](https://portswigger.net/research/http-desync-attacks-request-smuggling-reborn)
  · ✓ [HTTP/2: The Sequel is Always Worse (2021)](https://portswigger.net/research/http2)
  · ✓ [Browser-Powered Desync (2022)](https://portswigger.net/research/browser-powered-desync-attacks)
  · ✓ [HTTP/1.1 Must Die (2025)](https://portswigger.net/research/http1-must-die)
- **HTTP Garden (2024).** Kallus & Anantharaman. Dozens of CVEs across Apache, nginx, H2O,
  Node, Gunicorn, Puma, Tornado, etc. — see repo README for list. Method: differential fuzzing.
- Node.js had a run of smuggling CVEs 2020–2021 (CVE-2020-8201, -8287, CVE-2021-22959, -22960) — llhttp leniency.

### URL
- **A New Era of SSRF (2017).** Orange Tsai. cURL vs PHP vs Python vs Node URL parsers
  disagree on host; used for GitHub Enterprise RCE. Method: hand comparison across langs.
  ✓ [Black Hat slides](https://www.blackhat.com/docs/us-17/thursday/us-17-Tsai-A-New-Era-Of-SSRF-Exploiting-URL-Parser-In-Trending-Programming-Languages.pdf)
  · ✓ [GHE chain](https://blog.orange.tw/2017/07/how-i-chained-4-vulnerabilities-on.html)
- **Breaking Parser Logic (2018).** Orange Tsai. Path normalization differentials across
  nginx/Apache/Tomcat/Spring (`..;/`). ✓ [slides](https://i.blackhat.com/us-18/Wed-August-8/us-18-Orange-Tsai-Breaking-Parser-Logic-Take-Your-Path-Normalization-Off-And-Pop-0days-Out-2.pdf)
- **Exploiting URL Parsing Confusion (2022).** Claroty Team82 + Snyk. 16 parsers, 5 classes of
  confusion, 8 CVEs. Method: systematic cross-library test matrix. ✓ [report](https://claroty.com/team82/research/exploiting-url-parsing-confusion)
- **Confusion Attacks on Apache httpd (2024).** Orange Tsai. Filename / DocumentRoot /
  handler confusion from `r->filename` semantics. ✓ [write-up](https://blog.orange.tw/posts/2024-08-confusion-attacks-en/)
- Background tension: WHATWG URL Standard vs RFC 3986 — two specs, both "correct".

### JSON
- **Parsing JSON is a Minefield (2016).** Seriot. Differential over ~50 parsers; RFC 7159
  under-specification (duplicate keys, number precision, nesting depth, BOM, scalars at top).
- **JSON Interoperability Vulnerabilities (2021).** Bishop Fox (Jake Miller). Duplicate keys,
  key collision via Unicode, large numbers → auth/business-logic bypass. ✓ [blog](https://bishopfox.com/blog/json-interoperability-vulnerabilities)

### XML / SAML
- **Duo SAML (2018).** Kelby Ludwig. XML comment inside NameID: canonicalizer vs text
  extraction differ → auth as another user. Hit python-saml, ruby-saml, saml2-js,
  OmniAuth. ✓ [advisory](https://duo.com/blog/duo-finds-saml-vulnerabilities-affecting-multiple-implementations) · ✓ [CVE-2017-11427](https://nvd.nist.gov/vuln/detail/CVE-2017-11427) (+11428–11430)
- **ruby-saml "Sign in as anyone" (2025).** GitHub Security Lab (Peter Stöckli). REXML vs
  Nokogiri parse the same document differently; signature verified on one tree, assertion
  read from the other. Method: source review, noticing two parsers in one lib. ✓ [write-up](https://github.blog/security/vulnerability-research/sign-in-as-anyone-bypassing-saml-sso-authentication-with-parser-differentials/) · ✓ [CVE-2025-25291](https://nvd.nist.gov/vuln/detail/CVE-2025-25291), CVE-2025-25292
- Lineage: XML Signature Wrapping (McIntosh & Austel 2005; Somorovsky et al. "On Breaking SAML" 2012) — the same shape a decade earlier.

### Email / SMTP
- **SMTP Smuggling (2023).** Timo Longin, SEC Consult. End-of-data sequence (`\r\n.\r\n`
  vs `\n.\n`) interpreted differently by outbound vs inbound servers → spoofing.
  Postfix/Sendmail/Exim. ✓ [write-up](https://sec-consult.com/blog/detail/smtp-smuggling-spoofing-e-mails-worldwide/) · ✓ [CVE-2023-51764](https://nvd.nist.gov/vuln/detail/CVE-2023-51764) (+51765, 51766)
- **Splitting the Email Atom (2024).** Kettle. RFC 822/5322 encoded-word & comment handling
  differs between validator and MTA → access-control bypass (GitHub, Zendesk, GitLab).
  ✓ [write-up](https://portswigger.net/research/splitting-the-email-atom)

### HTML (sanitizer vs browser)
- **mXSS (2013).** Heiderich et al. — innerHTML mutation: sanitizer sees safe tree, browser
  re-serializes and re-parses into a different one. † CCS 2013 · ✓ [Cure53 paper](https://cure53.de/fp170.pdf)
- **DOMPurify namespace-confusion bypasses (2020).** Michał Bentkowski. MathML/SVG namespace
  switching. ✓ [write-up](https://research.securitum.com/mutation-xss-via-mathml-mutation-dompurify-2-0-17-bypass/)

### PDF
- **PDF signature attacks (2019–2021).** Mladenov, Mainka, Schwenk et al. (Ruhr Bochum):
  incremental-update and shadow attacks — viewer's "what is signed" vs "what is shown".
  ✓ [pdf-insecurity.org](https://www.pdf-insecurity.org/)
- Polyglots (Ange Albertini / corkami) — one file, several valid parses by format.

### YAML
- "The Norway problem" (`NO` → `false` in YAML 1.1, string in 1.2) — spec-version differential, not a CVE but the cleanest grandma-explainable example of the genre.

## 3. Verified / grammar-first parsers (the FM side)
| Project | Org | Notes |
|---|---|---|
| ✓ [EverParse / 3D](https://github.com/project-everest/everparse) | Microsoft Research | F*; verified zero-copy parsers; shipped in Windows (Hyper-V). ✓ [USENIX Sec 2019](https://www.usenix.org/system/files/sec19-ramananandro_0.pdf) |
| ✓ [Daedalus](https://github.com/GaloisInc/daedalus) | Galois (SafeDocs) | Data-description language; PDF, NITF parsers; checks for ambiguity. |
| ✓ [Hammer](https://github.com/UpstandingHackers/hammer) | LangSec (Patterson) | Parser combinators for binary formats in C. |
| ✓ [Nail](https://pdos.csail.mit.edu/papers/nail:osdi14.pdf) | Bangert & Zeldovich, OSDI 2014 | Grammar → parser + generator; bijective by construction. |
| ~ Narcissus | Delaware et al., ICFP 2019 | Coq; derive correct-by-construction encoders/decoders. |
| ~ Lean 4 | — | `Std.Internal.Parsec`, Lean's own `Parser` are unverified; there is no canonical verified-parser story in Lean yet. **Opportunity.** |

## 4. Patterns worth formalizing
1. **Two-parser products** (ruby-saml, Android master key): the vulnerable system *itself*
   contains two parsers for the same input. Static check: "does this program parse
   input X with more than one grammar?"
2. **Length-vs-delimiter** (NUL prefix, CL/TE, SMTP end-of-data): one side counts, the other
   scans for a terminator. Formal: two different recognizers for "end of message".
3. **Canonicalize-then-check vs check-then-canonicalize** (SAML, path normalization, mXSS).
4. **Lenient vs strict** on the same RFC ("be liberal in what you accept" — Postel — is the
   root of most of this). Formal: L(strict) ⊂ L(lenient); the differential is L(lenient) \ L(strict).
5. **Spec under-determination** (JSON duplicate keys, URL host parsing): the RFC admits both
   readings. This is precisely deformalize's target: find the sentence that admits both.

## 5. People to know (for Zulip / asking)
Meredith Patterson, Sergey Bratus (LangSec); James Kettle (PortSwigger); Orange Tsai;
Ben Kallus (HTTP Garden); Peter Stöckli (GitHub Sec Lab); Evan Sultanik (Trail of Bits,
PolyFile); Tahina Ramananandro (EverParse); Nicolas Seriot (JSONTestSuite).
