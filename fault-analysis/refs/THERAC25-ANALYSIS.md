# Therac-25 through every paradigm — analysis

Companion prose to `steps.json` (the machine-readable walkthrough) and `../index.html` (the
interactive demo). Primary lens: **STPA/CAST** (the contemporary method). Facts trace to
**Leveson & Turner, "An Investigation of the Therac-25 Accidents," IEEE Computer, July 1993**
(RESOURCES.md §1); `~` marks anything stated from memory rather than that paper.

## Why Therac-25
It is the founding case of software safety and the cleanest "no part failed" accident: the
software did exactly what it was written to do. Between 1985 and 1987 a medical linear
accelerator delivered massive radiation overdoses. The causes were an *interaction*:
- a **concurrency race** between the operator-input task and the treatment-setup task;
- **hardware interlocks removed** — software was trusted to enforce what hardware used to;
- **code reused from the Therac-20**, whose identical bugs were *masked* by the Therac-20's
  hardware interlocks;
- **operator editing speed** — a fast correction to the prescription (within ~8 seconds)
  slipped past the setup task after it had latched. ~

No FMEA entry, no fault-tree leaf, no reliability number names this. That is the whole point.

## The contemporary analysis (STPA → CAST), step by step
The `steps.json` sequence is the detail; the arc:
1. **Losses & hazard** — the loss is patient overdose; fix the bad-state predicate `hazard`.
2. **Control structure** — operator → software → beam/turntable → patient, with an org level
   (AECL/regulator) above. The **beam→software feedback is missing**: software cannot observe
   the actual turntable position. (STPA step 1; this absence is the structural seed.)
3. **Control actions** — set-energy, set-filter, fire.
4. **Unsafe control actions (the grid)** — crossing each action with the four STPA guidewords
   yields **UCA1: fire the high-energy beam while the turntable is in field-light position**
   (no flattener in the path). This is a `∀`-over-the-grid completeness activity.
5. **Safety constraint = invariant** — UCA1 becomes **C1: never fire high energy unless the
   turntable is confirmed in the flattener position.**
6. **Why would C1 be violated?** — STPA's causal-factor step: the controller's *process model*
   (its belief about the turntable) diverges from reality because there is no feedback and a
   race updates state out from under it. C1 is provable **only under the assumption belief =
   reality** — an assumption the design silently relies on and the race breaks.
7. **CAST — replay** — construct the actual fast-edit trace; it *reaches* a firing state with
   `energy = high ∧ turntable = fieldLight`, i.e. a constructive `¬C1`. In formal terms the
   accident **is a model-checker counterexample** to C1.
8. **CAST — climb the hierarchy** — the false "belief = reality" assumption is attributed
   upward: AECL reused code and under-tested concurrency; interlocks were removed; the
   regulator required no independent check. The assumption becomes an **explicit named axiom**
   that nobody was entitled to.
9. **Fix = enforce the invariant** — restore independent feedback / a hardware interlock that
   acts as a **runtime monitor** of C1 (Schneider: safety properties are exactly the
   enforceable ones). UCA1 becomes unreachable.
10. **Safe-loosening check** — the demo's punchline: when "ops" asks to drop the interlock for
   throughput, the tool demands a certificate that the hazard invariant still holds without it.
   It is unprovable, so the loosening is **refused with the accident it would re-enable** —
   literally the 1980s decision, blocked. The ratchet is on `H` (no overdose), not on the
   implementation constraint beneath it.

## The same case in the preceding paradigms (what each would have done)
- **FMEA (Era 1, 1949):** enumerates component failure modes. Every component was nominally
  working, so FMEA's table is silent on the actual cause. *Would not find it.*
- **FTA (Era 2, 1962):** Boolean failure logic. "Software issues a command that is correct per
  its specification" is not a failure leaf; the race and timing are dynamics FTA doesn't model.
  *Weak.*
- **HAZOP (Era 2, ~1970):** guideword deviations. "MORE dose than intended" is a deviation it
  would list — so HAZOP at least *names* the symptom — but not the control-coordination cause.
  *Partial.*
- **PRA (Era 3, 1975):** quantifies with event/fault trees and yields a risk number. For
  systematic software faults the number is both wrong and falsely reassuring. *Misleading.*

## The same case in the successive paradigms
- **FRAM (Era 5, 2004):** models everyday performance variability and its "resonance." It
  captures operator editing speed as *normal* variability coupling with setup timing — a real
  insight — but resists a crisp forbidden transition and is hard to falsify. *Descriptive,
  complementary.*
- **Safety-II:** asks why the thousands of *safe* treatments went right; valuable for
  understanding operator adaptation, but alone it doesn't name the invariant the accident
  violated. *Complementary, not sufficient.*
- **Safety-III (Leveson, 2020):** argues system safety already *is* the resilient approach;
  on Therac-25 it reaches the same control-theoretic result as STPA/CAST. *≈ STPA/CAST.*

## The honest boundary (CONCEPT §7)
Mechanically checkable here: control-graph well-formedness, UCA-grid coverage, constraint
non-vacuity (`C1` really excludes `UCA1`), the accident as a counterexample, and the
safe-loosening obligation (`C1' ⊨ ¬hazard`?). **Judgement, not mechanizable:** did we draw
the right control structure and find the right hazards? That is where the accident corpus +
an LLM scaffold help, and where a human/agent is still in the loop.

## The one-line thesis the demo lands
> The Therac-25 accident is a *counterexample to a safety invariant that nobody had written
> down*. STPA writes the invariant before the accident; CAST exhibits the counterexample after;
> Lean checks both; and "safe loosening" is what stops you from deleting the invariant later.
