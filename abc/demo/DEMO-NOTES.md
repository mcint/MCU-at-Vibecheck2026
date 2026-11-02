# DEMO-NOTES — abc / abc-1 (`demo/index.html`)

## How to run
- **file://** — just open `demo/index.html` in a browser. Single self-contained file (37 KB, vanilla JS/CSS, no CDN).
  The static plots are referenced relatively (`../plots/*.svg`), so keep `demo/` next to `plots/`.
- **served** — from the project root: `python3 -m http.server 8765` then
  `http://localhost:8765/demo/index.html` (any static server works; relative paths only).
- **embedded** — `demo/index.html?embed=1` hides the header; a fixed "open standalone ↗" link stays top-right.
  Designed for an iframe ≈1100×700 (two cards per row; scrolls inside the frame if the quick-read is open).
- Keys: `←` `→` scenes · `a` `b` `c` play · `u` undo · `r` reset. Hash `#s1…#s5` deep-links a scene.
  The quick-read "skip" is remembered in `localStorage['abc-demo-skip']`.
- The `#print axioms` lines shown on the page were produced by `lake env lean demo/_axioms.lean`
  (file kept for provenance; not part of the lake build).

## 90-second presenter script
1. **(Scene 1, 15 s)** "Three numbers. Click one: it doubles, the others lose one. Two variants, one `step`
   function, one flag: abc floors at 0 — and 0·2 = 0, so a zero is forever; abc-1 has no floor, negatives
   double *down*." Start (1,0,5), press `b` → (0,0,4). Flip to abc-1, start (0,−1,5), press `b` → (−1,−2,4).
2. **(Scene 2, 25 s)** "Can you keep all three alive? The answer flips at 2 → 3 → 4." Pick (2,2,2), press
   anything twice — DEAD; `doomed2` says *every* play. Pick (3,3,3), click the 3-cycle — alive forever, but the
   red line `min ≤ 3` is `trapped3`: every play of every length, proven with a 97-state invariant, not
   enumeration. Pick (4,4,4), click "grow ×3": `unbounded4_score` — name any M, some play beats it.
3. **(Scene 3, 15 s)** "Now maximise the product in abc. Steward's heuristic: keep factors balanced —
   `cube_balance` is the algebra. In 6 turns from (4,4,4) the best is exactly 336 = 6·7·8
   (`prodPar6_sat_bound`); try to beat it — you can't."
4. **(Scene 4, 25 s)** "Same heuristic in abc-1 from (1,1,1)… play the balanced split" (click split) "— now
   spam `a`" (click spam) "— bigger. Two negatives make a positive product and the −1 drag is *free*
   magnitude for the two you ignore. `spam_optimal` is for **every** play and **every** N ≥ 2, via a box
   invariant plus a sign split; `spam_attains` says spam hits the bound. Axioms: only propext,
   Classical.choice, Quot.sound."
5. **(Scene 5, 10 s)** "Tweak the problem: monotone rescoring — same answer, one line. Two numbers — spam
   *fails*: one negative, product ≤ 0 (`spam2_nonpos`); the 2-D optimum dips first (`bb a⁶` → 128,
   `par2_8_bound`). The theorem rests on sign parity; the smaller problem is the harder one."

## What IS proven (Lean 4, kernel-checked, zero `sorry`, no `native_decide`)
`step_agree`, `zero_forever(_run)`, `doomed2`, `F_closed`/`F_le3`, `trapped3`, `survive3`, `step_mono`/`run_mono`,
`step_dbl`/`run_dbl`, `grow_doubles`, `unbounded4`, `unbounded4_score`, `le_bestFrom`/`le_bestProd`,
`spread_loses`, `cube_balance`, `prodPar6_sat(_tight/_bound)`, `prodPar9_nosat(_tight/_bound)`,
`spam35_val`/`split35_val`/`spam_beats_split` (Abc.lean); `box_run`, `two_neg_bound`, `spam_optimal`,
`spam_attains` (Optimal.lean); `spam_optimal_mono`, `spam2_nonpos`, `par2_8(_tight/_bound)`,
`box_loose_2d`, `sumPar6(_tight)` (Perturb.lean). Per-theorem `#print axioms` output is quoted verbatim
on the page (some use fewer than the three standard axioms; `spam_beats_split` uses none).

## What is NOT proven
- **The web page itself.** Its JS re-implements `step`/`step2` only for interactivity; nothing on the
  page is checked by Lean. If the page ever claims a play beats a proven bound, the JS is wrong, not the proof.
- **The "exact DP" claims** beyond the stated horizons: product-optimal rotation to N=12 ((18,19,20)),
  abc-1 spam-optimality agreeing with DP to N=14, 4-number optimum, per-coordinate √/log rescorings,
  drag −2/−3 and ×3 doubling — all Python exploration only (marked "not formalized" in the table).
- **Par (max-min) for fixed N** (e.g. `bestFrom s4 9 = 10`) is `#guard`-checked in Tests.lean, not a theorem.
- `trapped3` is for abc only; for abc-1 the analogous dead-branch lemma ("negative is forever") is not done.
- Whether 4 is the exact threshold for **asymmetric** starts (e.g. (3,3,4)) is unexplored.
- The 2-D optimum is proven only at N=8 (`par2_8_bound`); the general formula ≈ 2^(N−2)(N−6) is DP only.
- Scene-4 verdict text computes the bound in JS floating point (exact up to N=40, which the input caps at).
