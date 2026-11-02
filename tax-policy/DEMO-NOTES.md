# DEMO-NOTES — tax-game ("Maya's $1 raise", Policy Lab)

Deliverable: **`demo/index.html`** — single self-contained page (22 KB, vanilla JS/CSS, no CDN).
The older full Policy Lab (`web/index.html`, 80 KB, three stacked demos) is still served at `/` and
linked from the demo header as "full lab"; it is not the thing to put on the projector.

## How to run

```sh
cd projects/tax-game
python3 demo.py --port 8768      # runs `lake build` first (~30 s cold), then serves on 127.0.0.1:8768
```

- Demo: <http://127.0.0.1:8768/demo>  (embed form: `/demo?embed=1`)
- Full lab: <http://127.0.0.1:8768/?policy=income>
- API used by the slider: `GET /api/ptc?income=<0..200000>` → JSON from `lake exe tax_game ptc <income>`
  (sent with `Access-Control-Allow-Origin: *` so the `file://` copy can also reach it).

**No server?** Open `demo/index.html` via `file://` (or from the root `demos/index.html` iframe).
Everything renders; the numbers come from a JS mirror of the Lean definitions and the status line
says "numbers: JS mirror (server not reachable)". If a server *is* running on 8768, the page auto-upgrades
to "numbers: compiled Lean (port 8768)" and shows a "✓ JS mirror agrees" badge per point.

**No API key needed.** The Claude feature lives only in the full lab (`Explore more`); the demo page never
calls a model. If `ANTHROPIC_API_KEY` is absent the full lab degrades to "unavailable" and native audits still work.

Checks: `python3 demo.py --check` → `lake build` + **23 unittest OK** (was 22; `test_ptc_slider_endpoint_and_demo_page` added).
`grep -rn sorry TaxGame Main.lean` → 0 hits. `lake build` prints every `#print axioms` line shown on screen.

Keys: `←` / `→` step scenes; the 5 scene chips are clickable; the explainer "skip" is remembered in
`localStorage['taxgame.skipExplainer']`.

## 90-second presenter script

1. **(0–15 s) Scene 1 — Meet Maya.** "Real 2026 rule: ACA premium credits stop at 400 % of the poverty line,
   $62,600. Maya earns exactly that. Credit $141/month, premium $520. Her boss offers a $1 raise. Take it?"
2. **(15–30 s) Scene 2 — Take the raise** (press →). "At $62,601 the credit is zero. Same plan, $661/month.
   She is $1,691 poorer for the year. That's the cliff — IRS rule, not our invention. The red curve is the
   whole-dollar Lean function."
3. **(30–45 s) Scene 3 — Repair.** "Hypothetical fix, also written in Lean: keep the credit at the line, taper it
   to zero over the next $7,825. Green curve. Same raise, premium still $520."
4. **(45–70 s) Scene 4 — What Lean proves.** Point at the right panel. "Two theorems, verbatim from
   `Interdomain.lean`. `current_has_cliff`: there exists an income where $1 costs $141 — witness 62,600, by
   `decide`. `proposed_no_cliff`: **for every** natural-number income, a $1 raise raises the monthly premium
   by at most $1 — a real ∀, proved via a Lipschitz lemma and `omega`. `#print axioms`: `propext`,
   `Quot.sound`, nothing else. No sorry, no native_decide."
5. **(70–90 s) Scene 5 — Attack it.** Drag the slider / type 70,000 / hammer "+$1 raise". "Every point you
   pick is re-run through the compiled Lean binary — see the 'native Lean · lake exe tax_game ptc N' badge —
   and the theorem instance lights green. Find a green step bigger than $1 and you've broken a kernel-checked
   theorem. You won't."

If asked "isn't this just a unit test?": the ∃ is deliberately a witness; the ∀ (`proposed_no_cliff`) is over
all of ℕ, with the band boundaries (46,950 / 62,600 / taper end 70,425) handled by case split, not enumeration.

## What is proven (and where)

`TaxGame/Interdomain.lean`:
- `current_has_cliff : ∃ income, currentPremiumPaid (income+1) = currentPremiumPaid income + 141` — no axioms.
- `proposed_no_cliff (income : Nat) : proposedPremiumPaid (income+1) ≤ proposedPremiumPaid income + 1` — `[propext, Quot.sound]`.
- `proposed_credit_lipschitz`, `proposedCredit_arith` (closed arithmetic form) — supporting lemmas.
- Pre-existing: `real_cutoff_cliff` (decide), `current_credit_zero_above_cutoff` (∀), `proposed_credit_bounded` (∀),
  `proposed_boundary_continuous`, `found_cliff_is_failure` (search-witness soundness).

## What is NOT proven

- Anything about Maya's **actual eligibility** or tax return: Lean checks a 5-line arithmetic model with stated
  constants (2025 one-person FPL $15,650; 9.96 % applicable percentage for the 300–400 % band; KFF 2026
  Texas state-average benchmark $661/month; Form 8962 whole-dollar rounding). Other FPL bands, family size,
  monthly reconciliation, employer-coverage tests, cost-sharing reductions, state aid are **out of scope**.
- That the taper is good policy or revenue-neutral; it is a hypothetical, not law.
- `proposed_no_cliff` bounds the **monthly premium** step at $1 per $1 of **annual** income. It does not say
  annual net income is monotone (one $1/month step is $12/year). A stronger "net income never falls" theorem
  would need a shallower taper; we chose to state exactly what is proved.
- The chart curves are drawn by the JS mirror (sampled every few dollars in wide zoom). The tiles and badges
  are Lean-computed when the server is up; the mirror is cross-checked against Lean at each queried point and
  the unit suite asserts agreement on 19 boundary incomes.
- The cliff itself was not discovered here; it is in the IRS 2026 instructions. The contribution is the
  pattern: rule → executable Lean → witness + soundness → repair → ∀-theorem → UI.

## Files touched today

- `TaxGame/Interdomain.lean` — new theorems above + `#print axioms` lines.
- `Main.lean` — `ptc <income>` CLI command.
- `demo.py` — `/demo` route, `/api/ptc` endpoint (strict input, CORS `*`, 400/503 handling).
- `demo/index.html` — new presentation page. `tests/test_demo.py` — one new test. `README.md` — pointers.
