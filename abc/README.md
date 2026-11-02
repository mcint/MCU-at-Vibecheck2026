# abc / abc-1 — click one to double it, the other two drop by one

**[problem]** three numbers, one click per turn; doubling one starves the others. Can you keep all three alive? Forever? Can they all *grow*? The answer flips at a starting value of 2 → 3 → 4, and that is not obvious from playing.
**[formal object]** `trapped3 : ∀ p : List Act, score (runFrom .sat ⟨3,3,3⟩ p) ≤ 3` — for *every play of every length*, proven by a 97-state invariant, not enumeration. Beside it: `doomed2`, `survive3`, `unbounded4_score`, `step_agree`.
**[on screen]** the REPL with three bars, the `DEAD`/`SINKING` status flipping, and `plots/*.svg` — log-scale trajectories generated from the proven `step`.

## Rules
`a`/`b`/`c`: the clicked value doubles; the other two decrement by 1. Score = `min a b c` (keep the weakest alive).
- **abc** (`Variant.sat`): values floor at 0. Since 0·2 = 0, **a zero is forever**.
- **abc-1** (`Variant.nosat`): no floor. A negative value **doubles downward** when clicked.
One `step` function, one flag. Rules as understood from steward 2026-10-31; objective (min) is my choice — say if it should be sum/product.

## Run
```
lake build && ./test.sh
lake exe abc abc 9            # play abc, 9 turns from (4,4,4);   keys a b c · u · r · ? · ! · q
lake exe abc abc-1 9 2,2,2    # play abc-1 from (2,2,2)
lake exe abc traj abc cbaabcacb 4,4,4   # CSV trajectory
python3 plots/plot.py         # regenerate plots/*.svg + plots/index.md (stdlib only)
```

## What is proven (Abc.lean, zero sorry, all kernel — no `native_decide`)
| theorem | plain English | how |
|---|---|---|
| `step_agree` | while all three are ≥ 1, abc and abc-1 are the same game | `omega` |
| `zero_forever` / `zero_forever_run` | in abc, a value that hits 0 stays 0 under every play | `omega` + induction |
| **`doomed2`** | from (2,2,2), *every* play has a zero after 2 moves | 9 cases by `decide` + zero_forever |
| `F_closed`, `F_le3` | the 97-state set F is closed under alive moves, and min ≤ 3 on F | `decide` over 97×3 |
| **`trapped3`** | from (3,3,3), *no play of any length* gets all three above 3 | invariant `s ∈ F ∨ hasZero s` |
| **`survive3`** | from (3,3,3), a play of length 3+3k ends alive at (4,3,2) for every k | enter + 3-cycle, induction |
| `step_mono`, `run_mono` | bigger state → bigger result, under any play | `omega` + induction |
| `step_dbl`, `run_dbl` | doubling the state first beats doubling after: run(2s) ≥ 2·run(s) | `omega` + induction |
| `grow_doubles` | the 9-move line `cbaabcacb` takes (4,4,4) to (10,10,13) ≥ (8,8,8) | `decide` |
| **`unbounded4`** / **`unbounded4_score`** | from (4,4,4), after k rounds every value ≥ 4·2^k; name any M, some play beats it | mono + dbl + induction |
| `le_bestFrom` | any play of length t scores ≤ `bestFrom` (the oracle is an upper bound) | induction |
| **`spam_optimal`** (Optimal.lean) | abc-1, product: *every* play of *every* length N ≥ 2 scores ≤ 2^N·(N−1)²; spam attains it | box invariant + sign split |

The feasible-states story, in one line: **start 2 — dead by turn 2; start 3 — immortal but capped at 3; start 4 — the sky.**
`F` was computed by BFS in Python but is *checked* in Lean (`F_closed`); the kernel never trusts the search.

## Second objective: the product a·b·c (steward's framing) — and a surprise
Steward's heuristic: `x² = (x+c)(x−c) + c²`, so keep the factors balanced; stronger for cubes.
Proved as algebra by `grind`: `spread_loses`, `cube_balance` ((x−1)·x·(x+1) < x³).

| variant | start | proven | play |
|---|---|---|---|
| **abc** (floor 0) | (4,4,4), N=6 | `prodPar6_sat_bound : ∀ p, prod ≤ 336 = 6·7·8` — the balanced rotation is *exactly* optimal; exact DP to N=12 ends at (18,19,20) | `cbaabc` |
| **abc-1** (no floor) | (1,1,1), N=9 | `prodPar9_nosat_bound : ∀ p, prod ≤ 32768 = 2⁹·(−8)·(−8)` — **single-key spam is exactly optimal** | `aaaaaaaaa` |
| abc-1 | (1,1,1), N=35 | `spam_beats_split`: spam = 2³⁵·34·34 ≈ 3.97e13; the "double a, then b, then c" split a¹²b¹¹c¹² ends at (4073, −22540, −90112) ≈ 8.3e12, **4.8× worse** (witnesses by `decide`, not a par) | — |

Why the balance heuristic holds in abc but fails in abc-1: in abc you *must* keep all three ≥ 1,
and the only trade is additive (−1 here, +x there) — AM-GM applies. In abc-1 the sign trick lets
two values be negative, doubling is multiplicative, and the −1 drag is *additive*: while `a`
doubles, the drag is a free magnitude gain for b and c (−10 → −11 is ×1.1 each, ×1.21 together),
which beats spending the turn doubling b. Exact DP agrees to N=14 (`tmp/explore.py`).
**Proven for all N (`Optimal.lean`):** `spam_optimal : ∀ p, 2 ≤ p.length → prod (run p) ≤ 2^N·(N−1)²`
and `spam_attains : prod (run (replicate N A)) = 2^N·(N−1)²`. Axioms: only the standard three
(`propext`, `Classical.choice`, `Quot.sound`); no `decide` over plays, no `native_decide`.

*How (steward's "no phase change" idea, made precise):* each coordinate starts at 1 and receives
k doublings and d decrements in some order. **Box invariant:** `2^k·(1−d) ≤ x ≤ 2^k` in every state,
whatever the order (`box_run`, induction on the play). That is the "no input-range shift": the
reachable region per coordinate is a box that depends only on counts. Then signs: an odd number of
negatives makes the product ≤ 0; all-nonnegative gives ≤ 2^N; two negatives give
`x·|y|·|z| ≤ 2^kx · 2^ky(dy−1) · 2^kz(dz−1) = 2^N (dy−1)(dz−1) ≤ 2^N (N−1)²` since d ≤ N. Equality
forces dy = dz = N, i.e. the other two keys were never pressed — spam. ~200 lines, all `omega`/`grind`
plus three `Int.mul_le_mul` chains.

## Perturbations — what survives, what flips (`Perturb.lean`, `tmp/perturb.py`)
Steward's question: does the result hold on smaller/rescored versions?
| perturbation | result | status |
|---|---|---|
| any **monotone** rescoring f(a·b·c) — √, log | same optimum | `spam_optimal_mono`, one line from `spam_optimal` |
| per-coordinate **log**, summed (abc, floor) | = log of product → balanced rotation, same as product | DP agrees (`tmp/perturb.py`); not formalized (reals) |
| per-coordinate **√**, summed (abc, floor) | **flips to spam** (0,0,256): concave, but not enough against exponential growth | DP only |
| **sum** a+b+c (abc) | spam | `sumPar6 = 256` by `decide` |
| **1 number** | spam, 2^N | trivial |
| **2 numbers** (abc-1) | **spam fails** — one negative ⇒ product ≤ 0 (`spam2_nonpos`, all N). Optimum dips the doubled value below 0 first: `bb a⁶` → (−64,−2) = 128 at N=8; ≈ 2^(N−2)(N−6) | `par2_8_bound` by `decide`; `box_loose_2d`: the 3D-style box bound (2304) is loose by ~N here because both coordinates can't be "all decrements first" at once |
| **4 numbers** (abc-1) | spam fails (3 negatives); optimum `dc b^(N−2)` = 2^(N−2)(N−1)(N−2)(N−3), all four negative | DP only |
| drag −2, −3; doubling ×3 | spam, robustly | DP only |

Reading: the 3D theorem rests on **sign parity** — with an odd number of coordinates, spam leaves an even number of negatives and the untouched negatives are free magnitude. Even dimension forces a dip, the box invariant stops being tight, and the proof would need an *order* argument. The smaller problem is the harder theorem.

## Plots (`plots/index.md`)
grow · greedy · trapped · doomed · doomed-nosat · greedy-nosat · **prod-spam35 · prod-split35 · prod-balanced** (product as a dashed 4th line). Symlog y-axis (sign·log₂(1+|x|)) so abc-1's negatives plot. Data = `lake exe abc traj`, so the pictures are of the proven rules.

## Timings
`lake build` cold ≈ 15 s; `F_closed` decide ≈ 3 s; everything else < 1 s. `bestFrom` oracle at N=9 instant, N=12 ~1 s.

## Scratch
`tmp/` (gitignored): `explore.py` exact-DP/phase search, rasterized plot checks.

## Not proven / next
- Par (max-min) for fixed N is only `#guard`-checked (`bestFrom s4 9 = 10`), not stated as a theorem — add `par9` if wanted (`decide`, 3^9).
- `trapped3` is for abc. For abc-1 the same bound holds while alive (by `step_agree`) but the dead branch needs "negative is forever" — 10 lines, not done.
- Is 4 the exact threshold? `trapped3` + `unbounded4` say yes for symmetric starts; asymmetric starts (e.g. (3,3,4)) unexplored — a nice `decide` question.
