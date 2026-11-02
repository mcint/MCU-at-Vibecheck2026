# Policy Lab: find a bad rule, repair it, show the proof

Policy Lab opens with a representative 2026 federal Marketplace Premium Tax Credit (PTC) cutoff: a $1 increase in annual MAGI crosses the 400% FPL limit and removes a modeled $141 monthly credit. The user can compare a clearly hypothetical phase-out and inspect Lean's exact calculation. Extra experiments stay under **Explore more**, including the original fictional tax-benefit sandbox and an employee-discount example.

There are three worked examples:

| Example | Business question | Source and scope |
| --- | --- | --- |
| Tax × healthcare | What happens when a $1 annual MAGI increase crosses the 2026 PTC cutoff? | 2026 federal eligibility and contribution rules, plus a representative KFF Texas benchmark premium. Exact boundary proof; hypothetical repair labeled. |
| Tax and benefits | Can a $1 raise leave someone with $400 less to live on? | Deliberately fictional monthly rules, with a modeled resource floor. |
| Services-discount cap | Does an employee's entire $50 discount fit a $20 cap? | Restricted port of a pinned Catala tax-code example. |

For the separate vending-machine demo, see [Rulebreakers](../workflow-game/README.md).

For private Linux hosting and persistent services, see the shared [deployment guide](../../DEPLOYMENT.md).

## Quick start

From the repository root:

```sh
cd projects/tax-game
python3 demo.py --port 8768
```

- **Presentation demo (one chart, one MAGI slider, the ∃/∀ theorem pair):** <http://127.0.0.1:8768/demo> — also works offline by opening [demo/index.html](demo/index.html) directly; see [DEMO-NOTES.md](DEMO-NOTES.md).
- Guided tax × healthcare story and expandable original sandbox: <http://127.0.0.1:8768/?policy=income>.
- Employee-discount example: <http://127.0.0.1:8768/?policy=discount>.

Requirements: Python 3.10+, `elan`/`lake`, and Lean **4.35.0**, pinned in [lean-toolchain](lean-toolchain). The launcher builds before serving. First use may download the pinned toolchain. No Mathlib, third-party Python packages, or API key are required for the manual/native Lean demonstrations. The vending server uses a separate port, 8766.

## Walkthrough 1: tax × healthcare

The opening asks whether Maya should accept a $1 annual raise. She is a single 40-year-old Texas Marketplace customer with $62,600 annual MAGI. The $661 monthly benchmark is KFF's Texas state average for a 40-year-old, not a local plan quote.

1. **Ask Maya to take the raise.** At $62,600 (400% of the 2025 one-person FPL), Form 8962's 2026 contribution calculation rounds to $6,235 annually and $520 monthly. Against the representative $661 benchmark, the modeled monthly PTC is $141.
2. **Reveal the cliff.** Maya accepts. At $62,601, federal PTC eligibility ends and the premium becomes $661/month. Premiums rise $1,692 over a year; after her extra $1 income, she has $1,691 less before other taxes and expenses.
3. **Change the policy, then check it.** The hypothetical proposal keeps Maya's $141 monthly credit just above the line, then tapers it over the next half-FPL ($7,825). `real_cutoff_cliff` proves the current-rule boundary; `proposed_boundary_continuous` checks the proposed rule at that same edge. The UI shows the public-cost tradeoff. Lean checks the formulas, not Maya's personal eligibility.

This is an **inter-domain** interaction between tax-return income and healthcare premiums: a one-dollar annual increase in ACA household MAGI can remove a monthly credit. Under the displayed assumptions, annual income minus 12 benchmark premiums falls from $56,360 to $54,669, before ordinary income/payroll taxes and all other expenses.

The main graph makes the **cliff effect** visible. **X** is annual household MAGI; **Y** is the monthly benchmark premium after federal PTC. Lean supplies 301 exact whole-dollar points from $62,450 to $62,750. The hypothetical curve appears only after step 2. The chart is sampled evidence; the boundary theorem is separately kernel-checked.

Lean 4.35.0 runs locally: the launcher builds/kernel-checks the theorem and the server invokes `.lake/build/bin/tax_game` for native results.

This is a real federal eligibility rule with a representative state-average premium, not a personalized quote or full Form 8962 implementation. It assumes one eligible tax household enrolled in the benchmark Silver plan, with no disqualifying employer or government coverage. It excludes ordinary income/payroll tax, local plan rates, state assistance, cost-sharing reductions, life changes and final tax-return reconciliation. The 9.96% contribution formula is only modeled in the 300–400% FPL band. The original fictional housing/support model remains separately available under **Explore more**.

**Who found the cliff?** The cutoff is in current IRS eligibility instructions; it was not discovered by this demo. The 2026 IRS rules restore the 400% FPL limit after a temporary 2021–2025 expansion. Native Lean searches a focused income interval to return the exact boundary case and checks the resulting arithmetic. See the source drawer in the demo and the [IRS PTC Q&A](https://www.irs.gov/affordable-care-act/individuals-and-families/questions-and-answers-on-the-premium-tax-credit), [2026 IRS contribution table](https://www.irs.gov/irb/2025-32_IRB), [2026 Form 8962](https://www.irs.gov/pub/irs-dft/f8962--dft.pdf), and [KFF 2026 benchmark data](https://www.kff.org/affordable-care-act/state-indicator/marketplace-average-benchmark-premiums/).

## Walkthrough 2: the original tax-benefit sandbox

Open **Explore more**, then use the separate original housing/work-support model below.

Press **Accept $1 raise**. The original policy produces:

| Monthly amount | Before | After | Why it changes |
| --- | ---: | ---: | --- |
| Work earnings | $1,199 | $1,200 | The employer adds $1. |
| Tax | $119 | $120 | 10% of earnings, rounded down. |
| Housing support | $400 | $0 | Eligibility ends at $1,200 earnings. |
| Money to live on | **$1,480** | **$1,080** | Earnings minus tax, plus eligible support. |

The sandbox pairs each change with the exact Lean rule and its native before/after evaluation. The repair replaces abrupt cutoffs with a gradual taper and uses total work earnings consistently. Its result and support cost are shown below; full assessments and raw execution traces are expandable.

Next, choose a promise in **Let Lean audit the policy**:

1. **Find a problem.** The native executable searches starting wages $0–$2,500, with side income zero, using the selected action sequence.
2. **Inspect the evidence.** It finds starting wages 1199 for a floor-crossing raise, 1000 for unequal treatment of income labels, or 222 for a repeated payout beyond allocation.
3. **Apply the demonstrated repair.** The same household/actions replay under the repaired rule.
4. **Read the general guarantee.** The interface identifies the relevant kernel-checked theorem.

These are actual searched witnesses, with search-result soundness proved in [Audit.lean](TaxGame/Audit.lean). The search is bounded to those tests. Lean does not invent the repair automatically; the proposed repair has separate general proofs.

## Reading the graph

- **X-axis:** monthly work earnings before tax, including wages and side income.
- **Y-axis:** money to live on after tax and eligible support, before living expenses.
- **Orange:** original rules. **Green:** repaired rules.
- **Dashed $1,200 line:** the minimum resource floor on Y, not an earnings cutoff on X.

Both axes display dollar/month units. Vertical ticks, the calculation, and current-dot readouts are explicit. At $1,200 earnings, the original rules give $1,080 resources and the repaired rules give $1,740. Curves and current amounts come from native Lean; side income is held at the value stated below the chart.

## Walkthrough 3: the services-discount cap

Select **Employee discount**, or open its direct link above.

1. Start with customer price **$100**, employee payment **$50**: the actual discount is **$50**.
2. **Check this claim with Lean.** Claiming all $50 exceeds the modeled 20%-of-customer-price cap of **$20**.
3. **Apply the cap and show the proof.** The modeled qualified portion is `min(50, 20) = 20`; $30 lies above this cap.
4. Change employee payment to **$90** and check again. The valid smaller $10 discount is preserved.

Business amounts, the cap calculation, and the general bound theorem appear side by side. Editing prices clears stale evidence/proof. Customer prices must be whole dollars divisible by five, from 5 to 10,000; employee payment must lie between zero and customer price.

This example assumes the employee and service qualify. It models only the cap calculation, not every eligibility condition or total tax liability. The amount above the cap is **not a tax bill**. The source pattern is also described in [IRS Publication 15-B](https://www.irs.gov/publications/p15b).

## What Lean proves

| Property | Main declaration |
| --- | --- |
| Current law has an income where a $1 raise adds $141/month to the premium (witness 62,600) | `Interdomain.current_has_cliff` |
| Under the hypothetical taper, **for every** income a $1 raise raises the monthly premium by at most $1 | `Interdomain.proposed_no_cliff` (via `proposed_credit_lipschitz`) |
| 2026 cutoff arithmetic yields $141 PTC at $62,600 and $0 at $62,601 | `Interdomain.real_cutoff_cliff` |
| Every modeled household income above 400% FPL receives zero federal PTC | `Interdomain.current_credit_zero_above_cutoff` |
| Hypothetical taper has the same credit immediately on either side of the cutoff | `Interdomain.proposed_boundary_continuous` |
| Hypothetical credit never exceeds the modeled benchmark premium | `Interdomain.proposed_credit_bounded` |
| Native search result satisfies the stated cliff predicate | `Interdomain.found_cliff_is_failure` |
| Resources reach the modeled $1,200 floor for all natural earnings | `repaired_floor` |
| More total earnings cannot reduce resources | `repaired_monotone` |
| Equal total work earnings receive equal resources | `repaired_source_neutral` |
| Accepted repaired histories preserve the floor, event checks, $1,200 household allocation, and one award per assessment | `accepted_repaired_history_safe` |
| Each returned native audit witness satisfies its failure predicate | `Audit.found_raise_is_failure`, `found_source_is_failure`, `found_retry_is_failure` |
| The capped discount never exceeds either the actual discount or customer price divided by five | `Repos.service_cap_bounded` |

The repaired income formula uses net earnings `n = total - floor(total/10)` and support `max(0, 1200 - floor(n/2))`. Whole-unit tax rounding can make a $1 raise neutral; the theorem promises nondecreasing resources, not a strict increase for every unit.

[Verify.lean](TaxGame/Verify.lean) establishes an assessment invariant, proves preservation and reachability, and bridges accepted replay to safety. Filing fixes this period's assessment; later retries acknowledge it without another payout. These induction theorems cover histories of arbitrary length. The HTTP interface separately limits starting income to 0–5000 per source and histories to 24 actions.

The floor, source-neutrality, and accepted-history theorems apply to the original sandbox model. The federal PTC model is in separate declarations in `Interdomain.lean`; its household and premium assumptions are listed in the story's source drawer.

General proofs are kernel-checked at build time; displayed examples execute through compiled Lean. No `sorry`, custom axioms, or `native_decide` appears in the new TaxGame code. Builds print the principal dependencies, using standard `propext`, `Quot.sound`, and (for a bound proof) `Classical.choice` where required.

## Actual GitHub reuse

| Repository | What this demo uses | Assurance boundary |
| --- | --- | --- |
| [LeanContracts](https://github.com/tripp-smith/leancontracts/tree/b9fc2e85897774decd01126f1b2e6a943adabd91) | Unmodified `Basic.lean` and `Semantics.lean`, compiled and executed to cross-check original support through its Contract/Observable DSL. | Float/integer agreement is a runtime check, not a universal equivalence proof. |
| [Catala examples](https://github.com/CatalaLang/catala-examples/blob/9e251b932288cf5f4a74af072d203144a057494b/us_tax_code/section_132.catala_en) | Preserved section 132 source and an attributed exact-integer port of the displayed services-cap case. | Catala's compiler is not run; the port is restricted to its stated inputs and cap assumptions. |

Original Apache-2.0 licenses are retained under [vendor/](vendor/). [provenance.json](vendor/provenance.json) records immutable revisions and hashes; [NOTICE.md](NOTICE.md) records attribution. The two LeanContracts modules were built on installed Lean 4.35.0; its original 4.29.1 pin and full upstream package are not claimed tested.

## Optional Claude suggestions

Under **Explore more**, open **Optional: ask Claude to look for another problem**. These suggestions concern the original housing/work-support sandbox. Suggestions are untrusted; native replay supplies accepted/rejected actions and actual violations. The same plans run against original and repaired rules. Unsuccessful and rejected plans remain visible.

Set `ANTHROPIC_API_KEY` or `ANTHROPIC_KEY` on the server or in the existing repo/workspace `.env`. Optional `ANTHROPIC_MODEL` selects a model; otherwise the adapter discovers an available model, preferring Haiku. Credentials are never sent to the browser.

Each process permits three generations, with three plans per call, eight actions per plan, and 1,400 output tokens. No automatic retry or simulated provider fallback occurs. Public fictional rules are supplied without known witnesses, proof labels, or curve data.

Runtime recordings in `runs/tax-ai-latest.json` are ignored by Git. A fresh checkout has no recorded run until you explicitly generate one; native audits work without it. Captured historical reports are in the [validation ticket](../../tickets/in-progress/tax-benefit-game/evidence/). One development run produced one old-rule failure and two unsuccessful plans; the paired repaired replays stayed safe. This is not a benchmark or a proof derived from model failure.

## Build, test, and inspect from the CLI

```sh
# Builds the executable and runs 22 checks; no paid model calls.
python3 demo.py --check

# Search for the tax/healthcare interaction and report both policies.
lake exe tax_game interdomain

# One MAGI point under both rules, plus the $1-raise neighbour (feeds the demo slider).
lake exe tax_game ptc 62600

# Replay a specific original-sandbox household action.
lake exe tax_game play old 1199 0 raise1
lake exe tax_game play fixed 999 0 file,retry

# Run actual bounded native searches.
lake exe tax_game audit cliff
lake exe tax_game audit source
lake exe tax_game audit retry

# Evaluate the second policy case.
lake exe tax_game discount 100 50

# One explicit live model generation, saved locally.
python3 demo.py --ai-check old
```

Tests cover the cross-domain witness, exact bill accounting, endpoint failures/strict input, arithmetic boundaries, native search/witness replay, positive controls, idempotency, strict input, HTTP isolation, source execution, cap examples, and mocked model behavior. Browser evidence covers desktop/mobile, graph labels, both tabs, staged repairs, cancellation, editing, and source/proof access. See the [guided-story validation](../../tickets/in-progress/tax-guided-story/api-e2e-testing.md) and [original validation](../../tickets/in-progress/tax-benefit-game/validation.md).

## Scope and source map

The income rules are fictional monthly policies. Resources include **eligible** support; actual disbursements are tracked separately. The $1,200 allocation is assumed funding for one household, not a society-wide balanced budget. The model does not establish real poverty eradication, legal compliance, program take-up, or economic behavior. Benefit-cliff framing is informed by [Atlanta Fed research](https://www.atlantafed.org/research-and-data/publications/workforce-currents/2026/08/04/from-barrier-to-bridge-approaches-to-address-benefits-cliffs) and [CBO's tax-rate definitions](https://www.cbo.gov/topics/taxes/tax-rates).

- [Interdomain.lean](TaxGame/Interdomain.lean): new tax/healthcare composition, searched witness/soundness, premium bounds, and combined monotonicity.
- [Model.lean](TaxGame/Model.lean): policies, amounts, actions, and replay.
- [Verify.lean](TaxGame/Verify.lean): general arithmetic and all-history proofs.
- [Audit.lean](TaxGame/Audit.lean): bounded searches and soundness.
- [Repos.lean](TaxGame/Repos.lean): actual upstream evaluator use and cap port/proof.
- [Main.lean](Main.lean): native CLI, snapshots, curve and causal explanations.
- [demo.py](demo.py), [adversary.py](adversary.py), [web/index.html](web/index.html): server, optional proposer, and interface.

If loading fails, confirm the launcher is running and use its printed port. Rebuild with `lake build` or restart `python3 demo.py` if the native engine is unavailable. Stop this task-owned server with Ctrl+C.
