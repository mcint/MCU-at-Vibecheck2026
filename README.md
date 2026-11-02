# MCU · Vibecheck 2026

[FMxAI](https://fmxai.org) · [Vibecheck hackathon](https://fmxai.org/vibecheck/) — the usable formal methods hackathon, Oct 31 – Nov 1 2026, SF.

**Live site: https://mcint.github.io/MCU-at-Vibecheck2026/** — all demos, static, no install. Source: this repo.

| # | demo | live | what you see in 60 s | what Lean proves |
|---|---|---|---|---|
| 1 | **HTTP parser differentials** | [alef](https://mcint.github.io/MCU-at-Vibecheck2026/http-parser-differentials/index.html) · [v2 hinge+timeline](https://mcint.github.io/MCU-at-Vibecheck2026/http-parser-differentials/index-v2.html) · [v1 detailed](https://mcint.github.io/MCU-at-Vibecheck2026/http-parser-differentials/index-detailed.html) | one crafted request fanned out across parser profiles; pick front end × back end → DESYNC or SAFE; the bytes each parser keyed on are highlighted; history ↔ current timeline of the bug class | `refines_no_desync` — a stricter back end cannot be smuggled through; `desync_hinge` — every desync is two parsers keyed on different fields (`spec/`) |
| 2 | **Policy Lab — the $1 raise that costs $1,691** | [demo](https://mcint.github.io/MCU-at-Vibecheck2026/tax-policy/demo/index.html) | the 2026 ACA premium-tax-credit cliff on a slider; take the raise, lose the credit; repair the rule | `current_has_cliff` (witness) vs `proposed_no_cliff` — for **every** income a $1 raise costs ≤ $1 (`TaxGame/`) |
| 3 | **Fault-analysis walk-throughs** | [demo](https://mcint.github.io/MCU-at-Vibecheck2026/fault-analysis/index.html) | 737 MAX, TMI, Therac-25, Cloudflare 2019 through one control-safety lens; Safety-I/II/III rules; safe-loosening finale | the four scenarios as machine-checkable step specs (`analysis/`); Lean model next |
| extra | Rulebreakers (vending) | [demo](https://mcint.github.io/MCU-at-Vibecheck2026/vending/web/index.html) | a drink or your coin back — never both; a recorded Claude attack replays | `accepted_repaired_history_safe` — repaired policy safe for every move sequence |
| extra | abc / abc-1 | [demo](https://mcint.github.io/MCU-at-Vibecheck2026/abc/demo/index.html) · [plots](https://mcint.github.io/MCU-at-Vibecheck2026/abc/plots/index.html) | click one number to double it, the others drop; start 2 dies, 3 is capped, 4 is unbounded | `trapped3`, `unbounded4_score`, `spam_optimal` for every horizon (`abc/`) |

Team **MCU** — FMxAI Vibecheck (usable formal methods) hackathon, Oct 31 – Nov 1 2026, SF.

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
