# fault-analysis — a Lean-verified tutor & checker for *doing fault analysis correctly*

> Concept doc. The history/bibliography is `RESOURCES.md`; read its §0 ethos arc and §5
> reading paths first. This doc turns that into a buildable idea and connects it to the
> other Vibecheck strands. Status: `growing`.

## 1. The itch
Fault analysis (FMEA, FTA, HAZOP, STPA, CAST…) is a *skill*, taught by apprenticeship and
done inconsistently. `RESOURCES.md` §2 shows each method encodes a causal model with known
blind spots; practitioners routinely apply the wrong method, stop at "component failure"
(Era 1 thinking) for a problem that's an unsafe *interaction* (Era 2–4), or produce a hazard
list with no traceable link to a property anyone could check. Meanwhile **agents** are now in
the loop — writing code, operating systems, proposing changes — and need the same discipline,
plus a machine-checkable substrate so their analyses can be *trusted and improved*, not just
generated.

**The idea:** an application that *bootstraps a person or an agent into performing fault
analysis in the correct way*, where "correct" is not vibes but a set of **Lean-checked
structural and logical obligations** on the analysis artifact. It teaches by making the
right move the easy move, and refuses the unsound one with a counterexample.

## 2. The thesis it's built on (from RESOURCES.md §0, §3a, §6)
- Safety ≠ reliability; the unit of analysis is the **hazard / unsafe control action**, not
  the broken part (Leveson). → The tool is STPA/CAST-shaped, not FMEA-shaped, by default.
- **Safety = "nothing bad ever happens"** (Lamport 1977); safety properties are exactly the
  ones a **monitor can enforce** (Schneider 2000). → Every hazard becomes an *invariant*,
  and an invariant is something Lean can check and a runtime can guard.
- Translation table (RESOURCES §3a): hazard ≈ bad state; safety constraint ≈ invariant;
  unsafe control action ≈ forbidden transition; **CAST ≈ counterexample trace**. This
  dictionary is the whole bridge from safety engineering to Lean.
- "Which few properties are worth proving?" (§6.3 operationalized): *a property is worth
  proving iff a CAST analysis of a plausible accident would cite its violation as a causal
  factor.* → Accident reports are the generator for the property list. The tutor can ship a
  corpus of the RESOURCES §1 cases (Ariane 5, Therac-25, MCAS, …) as worked examples.

## 3. What the app does
A guided loop with Lean as the adjudicator at each step:

1. **Model the control structure.** User/agent declares components, control actions, feedback.
   Lean obligation: the control graph is well-formed (every control action has a controller
   and a controlled process; every loop has feedback) — a *totality/typing* check.
2. **Enumerate unsafe control actions (UCAs).** For each control action × the four STPA
   guidewords (not given / given / wrong timing / wrong duration). Obligation: coverage —
   no control action left without a UCA verdict (even "none"). This is a `∀`-over-the-grid
   completeness check, exactly the kind Lean is good at.
3. **Turn each UCA into a safety constraint = invariant.** Obligation: the constraint, as a
   predicate on system state, actually *excludes* the UCA's bad state (not a vacuous or
   mislabeled constraint). Lean checks `uca_state ⊨ ¬constraint`.
4. **Discharge or defer.** Either prove the design maintains the invariant (`∀ reachable,
   inv`), or register it as a **monitored** constraint (Schneider: safety ⇒ enforceable) with
   a runtime guard — honest partiality (RESOURCES §3c lightweight FM).
5. **CAST mode (post-incident):** given a trace, find which invariant it violates. Obligation:
   the trace is a genuine counterexample to a named constraint — turns blame-storming into a
   pointer at a specific missing/violated property.

The *tutor* layer uses the worked accident corpus + an LLM to scaffold: suggest the likely
method, propose UCAs, draft constraints — but **every suggestion is gated by the Lean
obligation above**, so the human/agent learns the shape of a sound analysis by seeing
unsound ones bounce. (Same "LLM proposes, Lean adjudicates" pattern as `../deformalize`.)

## 4. Safe loosening — the part worth dwelling on
Most safety tooling is a **ratchet that only tightens**. Real systems must also *loosen* —
remove a guardrail, widen a limit, grant a permission, relax a precondition — to gain
efficacy and efficiency. Doing it blindly is precisely Rasmussen's **migration to the
boundary** and Vaughan's **normalization of deviance** (RESOURCES §0 Era 4). So the hard,
interesting feature is making loosening *first-class and safe*.

**Definition.** A loosening replaces constraint `C` with a weaker `C'` (`C ⊨ C'`, more
behaviors allowed). It is **safe** iff there is a checkable certificate that the top-level
hazard-free invariant `H` still holds under `C'` — either
- `C'`-restricted system still proves `∀ reachable, ¬hazard` (static discharge), or
- the barrier `C` removed was **redundant** given the others (bow-tie: another barrier still
  covers the top event — `(⋀ other barriers) ⊨ H` without `C`), or
- the gap is covered by a **monitor** that re-imposes `C` only on the runs that would reach
  the hazard (Schneider enforceable safety; the minimal-intervention **shield** of
  `../fun-verification` §1b rung 8).

**Why this is the same move everywhere in this repo:**
- `../upsolve`: loosening a version bound (`^1.2` → `*`) is safe iff the evidence (symbols
  used ∩ symbols changed = ∅) certifies no breakage. Identical certificate shape.
- `../deformalize`: a minimal *edit* to a spec is a loosening; the tool's job is to decide
  whether it opens a hole (unsafe) or is admissible. Safe loosening is deformalize run with
  the sign flipped — instead of hunting the edit that breaks things, prove the edit that doesn't.
- `../fun-verification` shield: "intervene only when every choice loses" = the **tightest
  safe constraint**; safe loosening is the search *toward* that minimal constraint.
- `../parser-differentials`: "be liberal in what you accept" (Postel) is uncertified
  loosening — the entire CVE canon is what happens without the proof obligation.

**Supporting it in the app:**
- **Provenance on every constraint** — which hazard/UCA it guards, so a loosening request
  immediately surfaces *what it protects against* (kills normalization-of-deviance: you can't
  quietly relax a thing when the tool shows the accident it prevents).
- **Loosening as a proof obligation, not a toggle.** The UI asks for the certificate (static
  proof, redundancy argument, or monitor) before allowing `C'`.
- **Defeasible / budgeted loosening for agents.** An agent gets a sandbox + a "loosening
  budget": it may propose relaxations; the system certifies-or-rejects and *logs the attempt*,
  producing a learning signal (Safety-II: study what goes right) and an efficacy-improvement
  loop with rollback. This is how agents "use it for learning and system safety & efficacy
  improvement" — the tool is both curriculum and governor.
- **The ratchet is on the invariant `H`, not on `C`.** `H` (no hazard) never loosens; the
  *implementation constraints* beneath it may, as long as they still entail `H`. That
  separation is the whole trick, and it's a clean Lean statement.

## 5. Why it fits Vibecheck
- **Usable software, formally verified** (the brief): the app is genuinely useful (a fault-
  analysis tutor/checker), and its *core guarantees* — coverage, non-vacuity, invariant
  maintenance, safe-loosening certificates — are Lean-proved. The verification is the product,
  not a bolt-on.
- **Grandma demo:** split screen — left, a plain-English hazard ("the radiation beam fires at
  full power in a mode the operator thinks is low"); right, the Lean invariant and a red
  counterexample trace (Therac-25). Then a "loosen this limit" button: without a certificate
  it's refused with the accident it would re-enable; with one, it goes green. The audience
  *feels* the ratchet.
- **Agents as first-class users** is on-trend and underexplored: a verified substrate for
  agent-run safety analysis and self-governed capability loosening.

## 6. Minimum viable build (ordered)
1. Encode ONE worked case end-to-end in Lean (Therac-25 or MCAS): control structure → UCAs →
   invariants → a counterexample trace. The honest core.
2. The safe-loosening theorem on that case: a specific limit, its guarded hazard, and
   `C' ⊨ H` discharged (and a second limit where it *fails*, with the counterexample).
3. A thin tutor UI (web/TUI, reuse the `../fun-verification/viz` + shared challenge panel):
   step through the loop, show obligations turning green, mash the "loosen" button.
4. Corpus: 3–4 RESOURCES §1 cases as cards the user/agent can open.

## 6b. Scale — safety is the tip of a property hierarchy
A worked example traces *one* failed invariant. A real flight-control system has ~10^5–10^6
properties; safety invariants sit atop a much larger base of **functional-correctness** and
**basic-functionality** properties (does the mode transition at all? does the unit return a
value?). Two implications: (1) the tooling must *scale selection* — which of a million
properties are worth proving (CONCEPT §2: "those a CAST would cite" is the safety-tier filter;
lower tiers need their own filters). (2) the same certificate machinery (prove / monitor /
safe-loosen) applies at every tier, so descending from safety into functionality is a change of
*population*, not of *method*. The demo carries a one-line scale pointer to the state-space viz;
extending the ladder downward (fun-verification rungs) is a natural next axis.

## 7. Open questions
- How much of STPA's method is *mechanically checkable* vs irreducibly judgement? (Coverage,
  non-vacuity, invariant maintenance: yes. "Did you find the right hazards?": no — that's the
  LLM+corpus scaffold's job.) Name the boundary honestly.
- Is "prove a bound" literally Rasmussen's "stay in the envelope" with a prover for a
  regulator? (RESOURCES §6.1 — if yes, STPA constraints *are* the invariant list.)
- Unpredictable accidents (Perrow, Downer, RESOURCES §6.2): a proof only moves the
  unpredictability into the model's assumptions (Ariane 5). The tool should make assumptions
  *explicit and loosenable-with-proof*, not pretend to eliminate them.
- Does this become a 4th demo, or the *framing* that unifies upsolve/deformalize/fun-
  verification under "certified tightening and loosening"? Possibly the latter — decide with `vc-qpt`.
