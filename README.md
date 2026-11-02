# MCU · Vibecheck 2026

Team **MCU** — FMxAI Vibecheck (usable formal methods) hackathon. Five demos: build real
software, formally verify it, and show on screen *what Lean checked*.

Open **`index.html`** for all three embedded in one page, or open any demo folder standalone.

| demo | folder | viewing | the point |
|---|---|---|---|
| **HTTP parser differentials** | [`http-parser-differentials/`](http-parser-differentials/index.html) | **static** (offline) | one crafted request, N parsers, different framings → request smuggling; a front-end × back-end matrix shows which pairings desync |
| **Fault-analysis walk-throughs** | [`fault-analysis/`](fault-analysis/index.html) | **static** (offline) | 737 MAX, Three Mile Island, Therac-25, Cloudflare (2019) through one control-safety lens; Safety-I/II/III example rules; a safe-loosening finale |
| **Rulebreakers (vending)** | [`vending/`](vending/web/index.html) | **static** (recorded run) / server for live Lean | a drink or your coin back — never both; Claude attacks, Lean checks the repaired policy |
| **abc / abc-1** | [`abc/`](abc/demo/index.html) | **static** | the 2→3→4 feasibility ladder and `spam_optimal` for every horizon — all kernel-checked |
| **Policy Lab (tax cliff)** | [`tax-policy/`](tax-policy/README.md) | **server** (Lean-backed) | the 2026 ACA premium-tax-credit cliff: find the bad rule, repair it, Lean checks the repair ∀ income |

## Viewing
- **Static demos** (HTTP, fault-analysis): open `index.html` directly, or the folder's own
  `index.html`. No build, no network. Each inlines its own data.
- **Policy Lab**: Lean-backed, so it runs standalone rather than embedded —
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
