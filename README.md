# MCU · Vibecheck 2026

[FMxAI](https://fmxai.org) · [Vibecheck hackathon](https://fmxai.org/vibecheck/) — the usable formal methods hackathon, Oct 31 – Nov 1 2026, SF.

**Live site: https://mcint.github.io/MCU-at-Vibecheck2026/** — all demos, static, no install. Source: this repo.

**1 · HTTP parser differentials** — [matrix view](https://mcint.github.io/MCU-at-Vibecheck2026/http-parser-differentials/index.html) · [hinge + timeline](https://mcint.github.io/MCU-at-Vibecheck2026/http-parser-differentials/index-v2.html) · [detailed](https://mcint.github.io/MCU-at-Vibecheck2026/http-parser-differentials/index-detailed.html).
One crafted HTTP request is fanned out across parser profiles (strict RFC 9112, TE-first, CL-first, last-CL, TE-ignoring, obs-fold, bare-LF) and each column says how many body bytes it would frame, or that it rejects. Pick a front end and a back end and the pair lights **DESYNC** (they disagree where the next request begins — smuggling) or **SAFE** (the back end rejects). The bytes each parser keyed on are highlighted — the *hinge* — and a history ↔ current timeline marks which behaviours were found and fixed (Watchfire 2005, Kettle 2019, HTTP Garden 2024) and which still legitimately diverge today. Lean (`spec/`) proves `refines_no_desync` — a back end that accepts a subset of what the front end accepts cannot be smuggled through — and `desync_hinge` — every desync is two parsers keyed on *different* fields.

**2 · Policy Lab — the $1 raise that costs $1,691** — [demo](https://mcint.github.io/MCU-at-Vibecheck2026/tax-policy/demo/index.html).
The 2026 ACA premium-tax-credit cliff on an income slider: at $62,600 the credit is $141/month; a $1 raise zeroes it. Find the bad rule, repair it (taper the credit over the next $7,825), and watch both curves. Lean (`TaxGame/`) gives `current_has_cliff` — a concrete witness — against `proposed_no_cliff` — for **every** income, a $1 raise costs at most $1 under the repaired rule. The live page mirrors the Lean definitions in JS and upgrades to the compiled Lean binary when the local server is running.

**3 · Fault-analysis walk-throughs** — [demo](https://mcint.github.io/MCU-at-Vibecheck2026/fault-analysis/index.html).
737 MAX, Three Mile Island, Therac-25 and Cloudflare 2019 through one control-safety lens: hazard, constraint, unsafe control action, and the loosening that would have been safe. Safety-I/II/III example rules per scenario. The four scenarios are machine-checkable step specs (`analysis/*.json`); a Lean model of the invariants is the next step.

**Extras** — same method, smaller stakes. *Rulebreakers* ([demo](https://mcint.github.io/MCU-at-Vibecheck2026/vending/web/index.html)): a drink or your coin back, never both; a recorded Claude attack replays against the old rules and Lean checks every move of the repaired policy (`accepted_repaired_history_safe`). *abc / abc-1* ([demo](https://mcint.github.io/MCU-at-Vibecheck2026/abc/demo/index.html) · [plots](https://mcint.github.io/MCU-at-Vibecheck2026/abc/plots/index.html)): click one of three numbers to double it, the others drop by one; start at 2 and you are dead in two moves, at 3 immortal but capped, at 4 unbounded — and with the floor removed, spam beats any balanced play at every horizon (`trapped3`, `unbounded4_score`, `spam_optimal`, all kernel-checked).

Team **MCU** — FMxAI Vibecheck (usable formal methods) hackathon, Oct 31 – Nov 1 2026, SF.

## Deep links
The landing page keeps its state in the URL fragment: `#http`, `#tax`, `#fault`, `#vending`, `#abc`
select a tab; `#<tab>/<inner-state>` also forwards state into the embedded demo, and the outer URL
follows the demo as you click (same-origin iframe). Inner formats:
- HTTP v2: `#i=<input 1–8>&fe=<front profile 0–6>&be=<back profile 0–6>&view=compact|detail`
  → e.g. `#http/i=2&fe=2&be=1&view=detail` (CL.TE, CL-first front × TE-first back, detailed rows)
- Policy Lab: `#s=<scene 1–5>&i=<income>` → e.g. `#tax/s=5&i=70000`
- abc: `#s<scene 1–6>` → e.g. `#abc/s4` (the abc-1 sign trick)
Standalone pages accept the same inner fragment directly.

## Viewing
- **Static demos** (HTTP, fault-analysis): open `index.html` directly, or the folder's own
  `index.html`. No build, no network. Each inlines its own data.
- **Policy Lab**: the live page is a JS mirror of the Lean definitions; run the Lean-backed server for compiled-Lean numbers —
  `cd tax-policy && python3 demo.py --port 8768` then `http://127.0.0.1:8768/`. A screenshot is
  shown on the landing page; the Lean specs are in `tax-policy/TaxGame/`.

## What's included per demo
- **http-parser-differentials/** — `index.html` + `examples.json`; `refs/` (BACKGROUND, HTTP
  separability map, stack-fingerprinting); `spec/` (the Lean parser model).
- **fault-analysis/** — `index.html` + `analysis/*.json` (the four scenarios = the specs);
  `refs/` (CONCEPT, RESOURCES history, GLOSSARY, Therac analysis).
- **tax-policy/** — full component: `TaxGame/*.lean` (the formal spec), `demo.py`/`web/`
  (server + UI), `vendor/` (Catala source + LeanContracts), `DEMO.md`/`README.md`, screenshots.

## Credits & provenance
Built from the working repo `Vibecheck2026`. Policy Lab is Venkata's (tax × healthcare cliff,
grounded in 2026 PTC rules); the HTTP and fault-analysis demos are illustrative intuition pumps
(see each demo's in-page disclaimer and `refs/` for sourcing — Kettle/PortSwigger 2019 & HTTP
Garden for smuggling; Leveson/Hollnagel for the safety models).
