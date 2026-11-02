# MCU · Vibecheck 2026

[FMxAI](https://fmxai.org) · [Vibecheck hackathon](https://fmxai.org/vibecheck/) — the usable formal methods hackathon, Oct 31 – Nov 1 2026, SF.

**Live site: https://mcint.github.io/MCU-at-Vibecheck2026/** — all demos, static, no install. Source: this repo.

## In one line each
1. **HTTP parser differentials** — two parsers read the same bytes differently; make the back end stricter and that can't be exploited — proven.
2. **Policy Lab** — a $1 raise costs a family $1,691 under the 2026 tax rule; the repaired rule can never do that, for any income — proven.
3. **Fault analysis** — four famous accidents are each a counterexample to a safety rule nobody had written down; here it is written down.

*Extras:* **Rulebreakers** — a vending machine that can't give you both the drink and your coin, whatever Claude tries. **abc / abc-1** — a three-number clicking game where the kernel tells you which starting values are doomed, trapped, or unbounded.

## Each demo

### 1 · HTTP parser differentials
[matrix view](https://mcint.github.io/MCU-at-Vibecheck2026/http-parser-differentials/index.html) · [hinge + timeline](https://mcint.github.io/MCU-at-Vibecheck2026/http-parser-differentials/index-v2.html) · [detailed](https://mcint.github.io/MCU-at-Vibecheck2026/http-parser-differentials/index-detailed.html)

**What it is.** One crafted HTTP request is fanned out across parser profiles (strict RFC 9112, TE-first, CL-first, last-CL, TE-ignoring, obs-fold, bare-LF). Each column says how many body bytes it would frame, or that it rejects. Pick a front end and a back end: the pair lights **DESYNC** when they disagree where the next request begins — that gap is a smuggled request — or **SAFE** when the back end rejects.

**What to look at.** The *hinge*: the header bytes each parser keyed on are highlighted, and the readout says "front end keyed on `Content-Length[0]`; back end keyed on `Transfer-Encoding`". The detailed view adds, per column, how it parsed, the RFC sentence it leaned on, and whether it matches the Lean reference. A history ↔ current timeline marks which behaviours were found and fixed (Watchfire 2005, Kettle 2019, HTTP Garden 2024) and which still legitimately diverge today.

**What Lean proves** (`spec/ParserDiff/`). `refines_no_desync`: if the back end accepts a subset of what the front end accepts and agrees wherever both accept, no message can desync them in either direction — so a strict back end ends the attack class. `desync_hinge`: over the whole modelled message space, every desync is two parsers keyed on *different* fields; the divergence is always located at a hinge.

### 2 · Policy Lab — the $1 raise that costs $1,691
[demo](https://mcint.github.io/MCU-at-Vibecheck2026/tax-policy/demo/index.html)

**What it is.** The 2026 ACA premium-tax-credit cliff on an income slider. At $62,600 the credit is $141/month; a $1 raise zeroes it — same plan, $520 → $661 a month. Find the bad rule, repair it (taper the credit over the next $7,825), and watch both curves.

**What to look at.** Drag the slider, hammer "+$1 raise" at any income: every point is re-evaluated and the theorem instance lights green. The page mirrors the Lean definitions in JS and upgrades to the compiled Lean binary when the local server is running (`cd tax-policy && python3 demo.py --port 8768`).

**What Lean proves** (`TaxGame/`). `current_has_cliff`: a concrete witness income where $1 costs $141. `proposed_no_cliff`: for **every** income, a $1 raise raises the monthly premium by at most $1 under the repaired rule — a real ∀, via a Lipschitz lemma; axioms `propext`, `Quot.sound` only.

### 3 · Fault-analysis walk-throughs
[demo](https://mcint.github.io/MCU-at-Vibecheck2026/fault-analysis/index.html)

**What it is.** 737 MAX, Three Mile Island, Therac-25 and Cloudflare 2019 through one control-safety lens: hazard, constraint, unsafe control action, and the loosening that *would* have been safe. Switch scenarios top-left; each has Safety-I / II / III example rules.

**What to look at.** The moment in each walk-through where the accident becomes a counterexample to an invariant — and the finale, where a rule is loosened *without* reopening the hazard.

**What is formal.** The four scenarios are machine-checkable step specs (`analysis/*.json`). A Lean model of the invariants is the next step; the page says so.

### Extras — same method, smaller stakes
**Rulebreakers** ([demo](https://mcint.github.io/MCU-at-Vibecheck2026/vending/web/index.html)). A drink or your coin back, never both. A recorded Claude attack replays against the old rules and succeeds; against the repaired policy Lean checks every move (`accepted_repaired_history_safe`: no accepted history ends with both coin and drink with the player). Live attacks and the two-buyer round need the local server (`cd vending && python3 demo.py --port 8766`).

**abc / abc-1** ([demo](https://mcint.github.io/MCU-at-Vibecheck2026/abc/demo/index.html) · [plots](https://mcint.github.io/MCU-at-Vibecheck2026/abc/plots/index.html)). Click one of three numbers to double it; the other two drop by one. Start at 2 and you are dead in two moves (`doomed2`); at 3, immortal but never all above 3 (`trapped3`, every play of every length); at 4, unbounded (`unbounded4_score`). Remove the floor so values go negative, score by product, and spam beats every balanced play at every horizon (`spam_optimal`, no enumeration) — your balance heuristic's hidden premise was an additive trade.

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
