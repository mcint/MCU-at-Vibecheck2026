/-! # abc / abc-1 — click one number to double it; the other two decrement
Two variants of one rule:
  abc    : values saturate at 0           (and 0·2 = 0, so a zero is forever)
  abc-1  : values go negative             (and a negative doubles *downward*)
Score = min a b c — "keep the weakest one alive".  State is Int in both variants so the
variants are literally the same program with one flag.  Everything below is about this
`step`; the REPL and the plots run this same `step`. -/

namespace Abc

inductive Variant | sat | nosat
deriving Repr, DecidableEq

structure St where
  a : Int
  b : Int
  c : Int
deriving Repr, DecidableEq

inductive Act | A | B | C
deriving Repr, DecidableEq

def Act.ofChar : Char → Option Act
  | 'a' => some .A | 'b' => some .B | 'c' => some .C | _ => none
def Act.toChar : Act → Char
  | .A => 'a' | .B => 'b' | .C => 'c'

/-- saturation: `abc` clamps at 0, `abc-1` doesn't. -/
def clamp : Variant → Int → Int
  | .sat,   x => max 0 x
  | .nosat, x => x

def step (v : Variant) (s : St) : Act → St
  | .A => ⟨clamp v (2 * s.a), clamp v (s.b - 1), clamp v (s.c - 1)⟩
  | .B => ⟨clamp v (s.a - 1), clamp v (2 * s.b), clamp v (s.c - 1)⟩
  | .C => ⟨clamp v (s.a - 1), clamp v (s.b - 1), clamp v (2 * s.c)⟩

def score (s : St) : Int := min s.a (min s.b s.c)
def alive (s : St) : Bool := decide (1 ≤ s.a ∧ 1 ≤ s.b ∧ 1 ≤ s.c)

def runFrom (v : Variant) (s : St) : List Act → St
  | []          => s
  | act :: rest => runFrom v (step v s act) rest

/-- trajectory: every intermediate state (for plots). -/
def traj (v : Variant) (s : St) : List Act → List St
  | []          => [s]
  | act :: rest => s :: traj v (step v s act) rest

def bestFrom (v : Variant) : St → Nat → Int
  | s, 0     => score s
  | s, t + 1 => max (bestFrom v (step v s .A) t) (max (bestFrom v (step v s .B) t) (bestFrom v (step v s .C) t))

def bestPlay (v : Variant) : St → Nat → List Act
  | _, 0     => []
  | s, t + 1 =>
    let cands := [Act.A, .B, .C].map fun act => (act, bestFrom v (step v s act) t)
    let pick := cands.foldl (fun acc x => if x.2 > acc.2 then x else acc) (Act.A, bestFrom v (step v s .A) t)
    pick.1 :: bestPlay v (step v s pick.1) t

def s2 : St := ⟨2,2,2⟩
def s3 : St := ⟨3,3,3⟩
def s4 : St := ⟨4,4,4⟩

/-! ## Generic bound: any play of length t scores ≤ bestFrom. -/
theorem le_bestFrom (v : Variant) : ∀ (p : List Act) (s : St), score (runFrom v s p) ≤ bestFrom v s p.length := by
  intro p; induction p with
  | nil => intro s; simp [runFrom, bestFrom]
  | cons act rest ih =>
    intro s; simp only [runFrom, List.length_cons, bestFrom]
    cases act with
    | A => have := ih (step v s .A); omega
    | B => have := ih (step v s .B); omega
    | C => have := ih (step v s .C); omega

/-! ## Variant equivalence: while everything is alive, abc and abc-1 are the same game. -/
/-- If all three values are ≥ 1 before a move, saturation never triggers: both variants agree. -/
theorem step_agree (s : St) (h : alive s = true) (act : Act) : step .sat s act = step .nosat s act := by
  simp [alive] at h
  cases act <;> simp [step, clamp] <;> omega

/-! ## Rung "doomed": from (2,2,2) every play has a zero within 2 turns, and zero is forever. -/
def hasZero (s : St) : Bool := decide (s.a = 0 ∨ s.b = 0 ∨ s.c = 0)

/-- In abc a zero coordinate stays zero under every action (0·2 = 0, max 0 (0−1) = 0). -/
theorem zero_forever (s : St) (act : Act) (h : hasZero s = true) : hasZero (step .sat s act) = true := by
  simp [hasZero] at *
  cases act <;> simp [step, clamp] <;> omega

theorem zero_forever_run (p : List Act) : ∀ s, hasZero s = true → hasZero (runFrom .sat s p) = true := by
  induction p with
  | nil => intro s h; simpa [runFrom] using h
  | cons act rest ih => intro s h; exact ih _ (zero_forever s act h)

theorem hasZero_score (s : St) (h : hasZero s = true) (hs : alive s = true ∨ score s ≤ 0) : score s ≤ 0 := by
  simp [hasZero, alive, score] at *; omega

/-- **Doomed.** From (2,2,2), after any two moves some value is 0 — and then stays 0 forever. -/
theorem doomed2 : ∀ (x y : Act) (rest : List Act), hasZero (runFrom .sat s2 (x :: y :: rest)) = true := by
  intro x y rest
  show hasZero (runFrom .sat (step .sat (step .sat s2 x) y) rest) = true
  apply zero_forever_run
  cases x <;> cases y <;> decide

/-! ## Rung "trapped": from (3,3,3) you can live forever, but min never exceeds 3. -/
/-- The 97 alive states reachable from (3,3,3) (computed by BFS; *checked* below, not trusted). -/
def F : List St := [⟨1,1,2⟩, ⟨1,1,6⟩, ⟨1,1,8⟩, ⟨1,1,10⟩, ⟨1,1,12⟩, ⟨1,2,1⟩, ⟨1,2,2⟩, ⟨1,2,3⟩, ⟨1,2,4⟩, ⟨1,2,5⟩, ⟨1,2,6⟩, ⟨1,2,7⟩, ⟨1,2,8⟩, ⟨1,3,2⟩, ⟨1,3,4⟩, ⟨1,3,6⟩, ⟨1,4,2⟩, ⟨1,4,3⟩, ⟨1,4,4⟩, ⟨1,4,5⟩, ⟨1,5,2⟩, ⟨1,5,4⟩, ⟨1,6,1⟩, ⟨1,6,2⟩, ⟨1,6,3⟩, ⟨1,7,2⟩, ⟨1,8,1⟩, ⟨1,8,2⟩, ⟨1,10,1⟩, ⟨1,12,1⟩, ⟨2,1,1⟩, ⟨2,1,2⟩, ⟨2,1,3⟩, ⟨2,1,4⟩, ⟨2,1,5⟩, ⟨2,1,6⟩, ⟨2,1,7⟩, ⟨2,1,8⟩, ⟨2,2,1⟩, ⟨2,2,3⟩, ⟨2,2,4⟩, ⟨2,2,5⟩, ⟨2,2,6⟩, ⟨2,3,1⟩, ⟨2,3,2⟩, ⟨2,3,3⟩, ⟨2,3,4⟩, ⟨2,4,1⟩, ⟨2,4,2⟩, ⟨2,4,3⟩, ⟨2,5,1⟩, ⟨2,5,2⟩, ⟨2,6,1⟩, ⟨2,6,2⟩, ⟨2,7,1⟩, ⟨2,8,1⟩, ⟨3,1,2⟩, ⟨3,1,4⟩, ⟨3,1,6⟩, ⟨3,2,1⟩, ⟨3,2,2⟩, ⟨3,2,3⟩, ⟨3,2,4⟩, ⟨3,3,2⟩, ⟨3,3,3⟩, ⟨3,4,1⟩, ⟨3,4,2⟩, ⟨3,6,1⟩, ⟨4,1,2⟩, ⟨4,1,3⟩, ⟨4,1,4⟩, ⟨4,1,5⟩, ⟨4,2,1⟩, ⟨4,2,2⟩, ⟨4,2,3⟩, ⟨4,3,1⟩, ⟨4,3,2⟩, ⟨4,4,1⟩, ⟨4,5,1⟩, ⟨5,1,2⟩, ⟨5,1,4⟩, ⟨5,2,1⟩, ⟨5,2,2⟩, ⟨5,4,1⟩, ⟨6,1,1⟩, ⟨6,1,2⟩, ⟨6,1,3⟩, ⟨6,2,1⟩, ⟨6,2,2⟩, ⟨6,3,1⟩, ⟨7,1,2⟩, ⟨7,2,1⟩, ⟨8,1,1⟩, ⟨8,1,2⟩, ⟨8,2,1⟩, ⟨10,1,1⟩, ⟨12,1,1⟩]

/-- Invariant: in F, or has a zero. -/
def inv (s : St) : Bool := F.contains s || hasZero s

theorem F_closed : F.all (fun s => [Act.A, .B, .C].all fun act => inv (step .sat s act)) = true := by decide
theorem F_le3 : F.all (fun s => decide (score s ≤ 3)) = true := by decide

theorem inv_step (s : St) (act : Act) (h : inv s = true) : inv (step .sat s act) = true := by
  simp only [inv, Bool.or_eq_true] at h
  rcases h with h | h
  · have hc := F_closed
    simp only [List.all_eq_true] at hc
    have := hc s (by simpa [List.contains_iff_mem] using h) act (by cases act <;> simp)
    exact this
  · simp only [inv, Bool.or_eq_true]; exact Or.inr (zero_forever s act h)

theorem inv_run (p : List Act) : ∀ s, inv s = true → inv (runFrom .sat s p) = true := by
  induction p with
  | nil => intro s h; simpa [runFrom] using h
  | cons act rest ih => intro s h; exact ih _ (inv_step s act h)

theorem inv_score (s : St) (h : inv s = true) : score s ≤ 3 := by
  simp only [inv, Bool.or_eq_true] at h
  rcases h with h | h
  · have hl := F_le3
    simp only [List.all_eq_true, decide_eq_true_eq] at hl
    exact hl s (by simpa [List.contains_iff_mem] using h)
  · simp [hasZero, score] at *; omega

/-- **Trapped.** From (3,3,3), *no play of any length* ever gets all three above 3. -/
theorem trapped3 : ∀ p : List Act, score (runFrom .sat s3 p) ≤ 3 :=
  fun p => inv_score _ (inv_run p s3 (by decide))

/-- The sustaining 3-cycle: (4,3,2) —c→ (3,2,4) —b→ (2,4,3) —a→ (4,3,2). -/
def cyc : List Act := [.C, .B, .A]
theorem cyc_returns : runFrom .sat ⟨4,3,2⟩ cyc = ⟨4,3,2⟩ := by decide
theorem enter_cyc : runFrom .sat s3 [.A, .B, .C] = ⟨4,3,2⟩ := by decide

def forever (k : Nat) : List Act := [Act.A, .B, .C] ++ (List.replicate k cyc).flatten

theorem runFrom_append (v : Variant) (p q : List Act) : ∀ s, runFrom v s (p ++ q) = runFrom v (runFrom v s p) q := by
  induction p with
  | nil => intro s; rfl
  | cons a r ih => intro s; simp [runFrom, ih]

/-- **Survivable.** From (3,3,3) there is a play of every length 3+3k that ends alive at (4,3,2). -/
theorem survive3 : ∀ k, runFrom .sat s3 (forever k) = ⟨4,3,2⟩ := by
  intro k; unfold forever; rw [runFrom_append, enter_cyc]
  induction k with
  | zero => rfl
  | succ k ih => simp only [List.replicate_succ, List.flatten_cons, runFrom_append, cyc_returns]; exact ih

/-! ## Rung "unbounded": from (4,4,4) all three grow without limit. -/
def le (s t : St) : Prop := s.a ≤ t.a ∧ s.b ≤ t.b ∧ s.c ≤ t.c
instance (s t : St) : Decidable (le s t) := by unfold le; infer_instance
def dbl (s : St) : St := ⟨2*s.a, 2*s.b, 2*s.c⟩

theorem step_mono (v : Variant) (s t : St) (h : le s t) (act : Act) : le (step v s act) (step v t act) := by
  unfold le at *; cases v <;> cases act <;> simp [step, clamp] <;> omega

theorem run_mono (v : Variant) (p : List Act) : ∀ s t, le s t → le (runFrom v s p) (runFrom v t p) := by
  induction p with
  | nil => intro s t h; simpa [runFrom] using h
  | cons act rest ih => intro s t h; exact ih _ _ (step_mono v s t h act)

/-- Doubling the state before a move dominates doubling after: step (2s) ≥ 2·step s. -/
theorem step_dbl (v : Variant) (s : St) (act : Act) : le (dbl (step v s act)) (step v (dbl s) act) := by
  unfold le dbl; cases v <;> cases act <;> simp [step, clamp] <;> omega

theorem run_dbl (v : Variant) (p : List Act) : ∀ s, le (dbl (runFrom v s p)) (runFrom v (dbl s) p) := by
  induction p with
  | nil => intro s; unfold le; simp [runFrom]
  | cons act rest ih =>
    intro s; simp only [runFrom]
    exact
      let h1 := ih (step v s act)
      let h2 := run_mono v rest _ _ (step_dbl v s act)
      ⟨Int.le_trans h1.1 h2.1, Int.le_trans h1.2.1 h2.2.1, Int.le_trans h1.2.2 h2.2.2⟩

/-- A 9-move line that takes (4,4,4) to (10,10,13) ≥ (8,8,8) = 2·(4,4,4). -/
def grow : List Act := [.C,.B,.A,.A,.B,.C,.A,.C,.B]
theorem grow_doubles : le (dbl s4) (runFrom .sat s4 grow) := by decide

def growK : Nat → List Act
  | 0     => []
  | k + 1 => growK k ++ grow

/-- v k = 4·2^k, written recursively so doubling is definitional. -/
def v : Nat → Int
  | 0     => 4
  | k + 1 => 2 * v k
def pow (k : Nat) : St := ⟨v k, v k, v k⟩

theorem dbl_pow (k : Nat) : dbl (pow k) = pow (k+1) := rfl

theorem v_ge : ∀ k, 4 ≤ v k ∧ (k : Int) ≤ v k := by
  intro k; induction k with
  | zero => simp [v]
  | succ k ih => simp only [v]; omega

theorem dbl_mono (s t : St) (h : le s t) : le (dbl s) (dbl t) := by
  simp only [le, dbl] at *; omega

theorem le_trans' {s t u : St} (h1 : le s t) (h2 : le t u) : le s u := by
  unfold le at *; omega

/-- One round of `grow` from the k-th doubling of (4,4,4) reaches the (k+1)-th doubling. -/
theorem grow_pow : ∀ k, le (pow (k+1)) (runFrom .sat (pow k) grow) := by
  intro k; induction k with
  | zero => exact grow_doubles
  | succ k ih =>
    show le (dbl (pow (k+1))) (runFrom .sat (dbl (pow k)) grow)
    exact le_trans' (dbl_mono _ _ ih) (run_dbl .sat grow (pow k))

/-- **Unbounded.** From (4,4,4), after k rounds of `grow` every value is ≥ 4·2^k. -/
theorem unbounded4 : ∀ k, le (pow k) (runFrom .sat s4 (growK k)) := by
  intro k; induction k with
  | zero => unfold le; simp [growK, runFrom, pow, v, s4]
  | succ k ih =>
    simp only [growK, runFrom_append]
    exact le_trans' (grow_pow k) (run_mono .sat grow _ _ ih)

/-- Plain-English corollary: name any bound M; some play makes even the weakest value exceed it. -/
theorem unbounded4_score : ∀ M : Nat, ∃ p : List Act, (M : Int) ≤ score (runFrom .sat s4 p) := by
  intro M
  refine ⟨growK M, ?_⟩
  have h := unbounded4 M
  have hv := v_ge M
  simp only [le, pow, score] at *
  omega


/-! ## Second objective: the product a·b·c (steward's framing).
In abc-1 two negatives make the product positive, so sign games are allowed. -/
def prod (s : St) : Int := s.a * s.b * s.c

def bestProd (v : Variant) : St → Nat → Int
  | s, 0     => prod s
  | s, t + 1 => max (bestProd v (step v s .A) t) (max (bestProd v (step v s .B) t) (bestProd v (step v s .C) t))

theorem le_bestProd (v : Variant) : ∀ (p : List Act) (s : St), prod (runFrom v s p) ≤ bestProd v s p.length := by
  intro p; induction p with
  | nil => intro s; simp [runFrom, bestProd]
  | cons act rest ih =>
    intro s; simp only [runFrom, List.length_cons, bestProd]
    cases act with
    | A => have := ih (step v s .A); omega
    | B => have := ih (step v s .B); omega
    | C => have := ih (step v s .C); omega

/-! ### The balance heuristic, as algebra (proved by `grind`'s ring solver) -/
/-- x² = (x+c)(x−c) + c²: spreading two equal factors apart loses c². -/
theorem spread_loses (x c : Int) : (x + c) * (x - c) + c * c = x * x := by grind
/-- Three in a row lose to three equal: (x−1)·x·(x+1) = x³ − x < x³ for x ≥ 1. -/
theorem cube_balance (x : Int) (h : 1 ≤ x) : (x - 1) * x * (x + 1) < x * x * x := by grind
/-- In the saturating game the balanced rotation is exactly optimal: from (4,4,4) in 6 turns the
    best product is 336 = 6·7·8, reached by `cbaabc` — consecutive values, as balanced as parity allows. -/
theorem prodPar6_sat : bestProd .sat s4 6 = 336 := by decide
theorem prodPar6_sat_tight : runFrom .sat s4 [.C,.B,.A,.A,.B,.C] = ⟨6,7,8⟩ := by decide
theorem prodPar6_sat_bound : ∀ p : List Act, p.length = 6 → prod (runFrom .sat s4 p) ≤ 336 := by
  intro p h; have := le_bestProd .sat p s4; rw [h, prodPar6_sat] at this; exact this

/-! ### abc-1: the sign trick, and why spam beats the split -/
def s1 : St := ⟨1,1,1⟩
/-- abc-1 from (1,1,1), 9 turns: best product is 32768 = 2⁹·(−8)·(−8), by spamming one key. -/
theorem prodPar9_nosat : bestProd .nosat s1 9 = 32768 := by decide
theorem prodPar9_nosat_tight : prod (runFrom .nosat s1 (List.replicate 9 .A)) = 32768 := by decide
theorem prodPar9_nosat_bound : ∀ p : List Act, p.length = 9 → prod (runFrom .nosat s1 p) ≤ 32768 := by
  intro p h; have := le_bestProd .nosat p s1; rw [h, prodPar9_nosat] at this; exact this

/-- N = 35 witnesses (evaluation, not search): spam = 2³⁵·34·34; the "double a, then b, then c"
    split a¹²b¹¹c¹² is ≈4.8× smaller. Why: doubling is multiplicative, the −1 drag is additive, and
    while `a` doubles, the drag is a *free* magnitude gain for the two negatives. -/
def spam35  : List Act := List.replicate 35 .A
def split35 : List Act := List.replicate 12 .A ++ List.replicate 11 .B ++ List.replicate 12 .C
theorem spam35_val  : prod (runFrom .nosat s1 spam35)  = 39719857553408 := by decide   -- 2³⁵·34·34
theorem split35_val : runFrom .nosat s1 split35 = ⟨4073, -22540, -90112⟩ := by decide  -- product 8.27e12, 4.8× smaller
theorem spam_beats_split : prod (runFrom .nosat s1 split35) < prod (runFrom .nosat s1 spam35) := by decide

end Abc
