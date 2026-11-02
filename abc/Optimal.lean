import Abc
/-! # Spam is optimal in abc-1 for the product, at every horizon.
Per-coordinate box invariant: a value that has been doubled k times and decremented d times
satisfies 2^k·(1−d) ≤ x ≤ 2^k, in every state, whatever the order. Then a sign case split
bounds the product by 2^N·(N−1)², which spam attains. No enumeration anywhere. -/
namespace Abc

/-- lower corner of the box: 2^k · (1 − d) -/
def lo (k d : Nat) : Int := (2:Int)^k * (1 - (d:Int))
def hi (k : Nat) : Int := (2:Int)^k

theorem hi_pos (k : Nat) : 1 ≤ hi k := by
  unfold hi; induction k with
  | zero => simp
  | succ k ih => rw [Int.pow_succ]; omega

theorem lo_dec (k d : Nat) : lo k (d+1) = lo k d - hi k := by
  unfold lo hi; push_cast; grind
theorem lo_dbl (k d : Nat) : lo (k+1) d = 2 * lo k d := by
  unfold lo; rw [Int.pow_succ]; grind
theorem hi_dbl (k : Nat) : hi (k+1) = 2 * hi k := by
  unfold hi; rw [Int.pow_succ]; omega

def Box (x : Int) (k d : Nat) : Prop := lo k d ≤ x ∧ x ≤ hi k

theorem box_dec {x k d} (h : Box x k d) : Box (x - 1) k (d+1) := by
  unfold Box at *; have := lo_dec k d; have := hi_pos k; omega
theorem box_dbl {x k d} (h : Box x k d) : Box (2 * x) (k+1) d := by
  unfold Box at *; have := lo_dbl k d; have := hi_dbl k; omega

/-- counts of each action in a play -/
def cnt (act : Act) : List Act → Nat
  | [] => 0
  | x :: r => (if x = act then 1 else 0) + cnt act r

theorem cnt_sum (p : List Act) : cnt .A p + cnt .B p + cnt .C p = p.length := by
  induction p with
  | nil => rfl
  | cons x r ih => cases x <;> simp [cnt] <;> omega

theorem cnt_le (act : Act) (p : List Act) : cnt act p ≤ p.length := by
  have := cnt_sum p; cases act <;> omega

/-- The box invariant along any play from (1,1,1): coordinate i has been doubled `cnt i p` times
    and decremented `length − cnt i p` times. Stated for a general start inside boxes. -/
theorem box_run (p : List Act) : ∀ (s : St) (ka da kb db kc dc : Nat),
    Box s.a ka da → Box s.b kb db → Box s.c kc dc →
    Box (runFrom .nosat s p).a (ka + cnt .A p) (da + (p.length - cnt .A p)) ∧
    Box (runFrom .nosat s p).b (kb + cnt .B p) (db + (p.length - cnt .B p)) ∧
    Box (runFrom .nosat s p).c (kc + cnt .C p) (dc + (p.length - cnt .C p)) := by
  induction p with
  | nil => intro s ka da kb db kc dc ha hb hc; simp [runFrom, cnt]; exact ⟨ha, hb, hc⟩
  | cons x r ih =>
    intro s ka da kb db kc dc ha hb hc
    have hA := cnt_le .A r; have hB := cnt_le .B r; have hC := cnt_le .C r
    cases x with
    | A =>
      have := ih (step .nosat s .A) (ka+1) da kb (db+1) kc (dc+1) (box_dbl ha) (box_dec hb) (box_dec hc)
      simp only [runFrom, step, clamp, cnt, List.length_cons] at *
      simp only [if_pos rfl, if_neg (by decide : Act.A ≠ .B), if_neg (by decide : Act.A ≠ .C)] at *
      have e1 : ka + 1 + cnt .A r = ka + (1 + cnt .A r) := by omega
      have e2 : da + (r.length - cnt .A r) = da + (r.length + 1 - (1 + cnt .A r)) := by omega
      have e3 : db + 1 + (r.length - cnt .B r) = db + (r.length + 1 - (0 + cnt .B r)) := by omega
      have e4 : dc + 1 + (r.length - cnt .C r) = dc + (r.length + 1 - (0 + cnt .C r)) := by omega
      rw [e1, e2, e3, e4] at this; simpa using this
    | B =>
      have := ih (step .nosat s .B) ka (da+1) (kb+1) db kc (dc+1) (box_dec ha) (box_dbl hb) (box_dec hc)
      simp only [runFrom, step, clamp, cnt, List.length_cons] at *
      simp only [if_pos rfl, if_neg (by decide : Act.B ≠ .A), if_neg (by decide : Act.B ≠ .C)] at *
      have e1 : kb + 1 + cnt .B r = kb + (1 + cnt .B r) := by omega
      have e2 : db + (r.length - cnt .B r) = db + (r.length + 1 - (1 + cnt .B r)) := by omega
      have e3 : da + 1 + (r.length - cnt .A r) = da + (r.length + 1 - (0 + cnt .A r)) := by omega
      have e4 : dc + 1 + (r.length - cnt .C r) = dc + (r.length + 1 - (0 + cnt .C r)) := by omega
      rw [e1, e2, e3, e4] at this; simpa using this
    | C =>
      have := ih (step .nosat s .C) ka (da+1) kb (db+1) (kc+1) dc (box_dec ha) (box_dec hb) (box_dbl hc)
      simp only [runFrom, step, clamp, cnt, List.length_cons] at *
      simp only [if_pos rfl, if_neg (by decide : Act.C ≠ .A), if_neg (by decide : Act.C ≠ .B)] at *
      have e1 : kc + 1 + cnt .C r = kc + (1 + cnt .C r) := by omega
      have e2 : dc + (r.length - cnt .C r) = dc + (r.length + 1 - (1 + cnt .C r)) := by omega
      have e3 : da + 1 + (r.length - cnt .A r) = da + (r.length + 1 - (0 + cnt .A r)) := by omega
      have e4 : db + 1 + (r.length - cnt .B r) = db + (r.length + 1 - (0 + cnt .B r)) := by omega
      rw [e1, e2, e3, e4] at this; simpa using this


/-! ## From boxes to the product bound -/
theorem mul3_le {a b c A B C : Int} (ha : 0 ≤ a) (hb : 0 ≤ b) (hc : 0 ≤ c)
    (hA : a ≤ A) (hB : b ≤ B) (hC : c ≤ C) : a * b * c ≤ A * B * C := by
  have h1 : a * b ≤ A * B := Int.mul_le_mul hA hB hb (Int.le_trans ha hA)
  exact Int.mul_le_mul h1 hC hc (Int.mul_nonneg (Int.le_trans ha hA) (Int.le_trans hb hB))

/-- a nonnegative boxed value is ≤ 2^k -/
theorem box_pos {x k d} (h : Box x k d) : x ≤ hi k := h.2
/-- a negative boxed value has magnitude ≤ 2^k·(d−1), and forces d ≥ 2 -/
theorem box_neg {x k d} (h : Box x k d) (hx : x < 0) : -x ≤ hi k * ((d:Int) - 1) ∧ 2 ≤ d := by
  unfold Box lo hi at *; have := hi_pos k; unfold hi at this
  constructor
  · grind
  · refine Nat.le_of_not_lt fun hd => ?_
    have : (d:Int) ≤ 1 := by omega
    have : 0 ≤ (2:Int)^k * (1 - (d:Int)) := Int.mul_nonneg (by omega) (by omega)
    omega

def bound (N : Nat) : Int := (2:Int)^N * (((N:Int) - 1) * ((N:Int) - 1))

theorem pow_split (ka kb kc : Nat) : (2:Int)^ka * (2:Int)^kb * (2:Int)^kc = (2:Int)^(ka+kb+kc) := by
  rw [Int.pow_add, Int.pow_add]

/-- Two negatives, one nonnegative (the only sign pattern with a positive product): the product
    is at most 2^N·(N−1)². Stated for coordinates in any order via `x` nonneg, `y z` negative. -/
theorem two_neg_bound {x y z : Int} {kx dx ky dy kz dz N : Nat}
    (hx : Box x kx dx) (hy : Box y ky dy) (hz : Box z kz dz)
    (hx0 : 0 ≤ x) (hy0 : y < 0) (hz0 : z < 0)
    (hk : kx + ky + kz = N) (hdy : dy ≤ N) (hdz : dz ≤ N) :
    x * y * z ≤ bound N := by
  obtain ⟨hyb, hy2⟩ := box_neg hy hy0
  obtain ⟨hzb, hz2⟩ := box_neg hz hz0
  have e : x * y * z = x * (-y) * (-z) := by grind
  rw [e]
  have h1 : x * (-y) * (-z) ≤ hi kx * (hi ky * ((dy:Int) - 1)) * (hi kz * ((dz:Int) - 1)) :=
    mul3_le hx0 (by omega) (by omega) (box_pos hx) hyb hzb
  have h2 : hi kx * (hi ky * ((dy:Int) - 1)) * (hi kz * ((dz:Int) - 1))
          = (2:Int)^N * (((dy:Int) - 1) * ((dz:Int) - 1)) := by
    unfold hi; rw [← hk, ← pow_split]; grind
  have h3 : ((dy:Int) - 1) * ((dz:Int) - 1) ≤ ((N:Int) - 1) * ((N:Int) - 1) :=
    Int.mul_le_mul (by omega) (by omega) (by omega) (by omega)
  have h4 : (2:Int)^N * (((dy:Int) - 1) * ((dz:Int) - 1)) ≤ bound N := by
    unfold bound; exact Int.mul_le_mul_of_nonneg_left h3 (by have := hi_pos N; unfold hi at this; omega)
  omega

theorem sq_nonneg' (N : Nat) : 0 ≤ ((N:Int) - 1) * ((N:Int) - 1) := by
  cases N with
  | zero => decide
  | succ n => exact Int.mul_nonneg (by omega) (by omega)

theorem bound_nonneg (N : Nat) : 0 ≤ bound N := by
  unfold bound; have := hi_pos N; unfold hi at this
  exact Int.mul_nonneg (by omega) (sq_nonneg' N)

theorem all_nonneg_bound {x y z : Int} {kx ky kz N : Nat} (hN : 2 ≤ N)
    (hx : x ≤ hi kx) (hy : y ≤ hi ky) (hz : z ≤ hi kz)
    (hx0 : 0 ≤ x) (hy0 : 0 ≤ y) (hz0 : 0 ≤ z) (hk : kx + ky + kz = N) :
    x * y * z ≤ bound N := by
  have h1 : x * y * z ≤ hi kx * hi ky * hi kz := mul3_le hx0 hy0 hz0 hx hy hz
  have h2 : hi kx * hi ky * hi kz = (2:Int)^N := by unfold hi; rw [← hk, ← pow_split]
  have h3 : (2:Int)^N * 1 ≤ bound N := by
    unfold bound
    exact Int.mul_le_mul_of_nonneg_left (by
      have : (1:Int) ≤ (N:Int) - 1 := by omega
      calc (1:Int) = 1 * 1 := by simp
        _ ≤ ((N:Int) - 1) * ((N:Int) - 1) := Int.mul_le_mul this this (by omega) (by omega))
      (by have := hi_pos N; unfold hi at this; omega)
  omega

/-- **Spam is optimal at every horizon N ≥ 2.** For *every* play of length N from (1,1,1) in abc-1,
    the product is at most 2^N·(N−1)². (N ≤ 1 is `decide`.) -/
theorem spam_optimal (p : List Act) (hN : 2 ≤ p.length) :
    prod (runFrom .nosat s1 p) ≤ bound p.length := by
  have hb := box_run p s1 0 0 0 0 0 0 ⟨by decide, by decide⟩ ⟨by decide, by decide⟩ ⟨by decide, by decide⟩
  simp only [Nat.zero_add] at hb
  obtain ⟨ha, hbb, hc⟩ := hb
  have hsum := cnt_sum p
  have hA := cnt_le .A p; have hB := cnt_le .B p; have hC := cnt_le .C p
  unfold prod
  generalize hNdef : p.length = N at *
  generalize (runFrom .nosat s1 p).a = a at *
  generalize (runFrom .nosat s1 p).b = b at *
  generalize (runFrom .nosat s1 p).c = c at *
  rcases Int.lt_or_le a 0 with a0 | a0 <;> rcases Int.lt_or_le b 0 with b0 | b0 <;> rcases Int.lt_or_le c 0 with c0 | c0
  · -- three negatives: product negative
    have : a * b * c ≤ 0 := by
      have h1 : 0 ≤ a * b := Int.mul_nonneg_of_nonpos_of_nonpos (by omega) (by omega)
      exact Int.mul_nonpos_of_nonneg_of_nonpos h1 (by omega)
    exact Int.le_trans this (bound_nonneg N)
  · -- a,b negative, c ≥ 0
    have e : a * b * c = c * a * b := by grind
    rw [e]; exact two_neg_bound hc ha hbb c0 a0 b0 (by omega) (by omega) (by omega)
  · -- a,c negative, b ≥ 0
    have e : a * b * c = b * a * c := by grind
    rw [e]; exact two_neg_bound hbb ha hc b0 a0 c0 (by omega) (by omega) (by omega)
  · -- a negative only
    have : a * b * c ≤ 0 := by
      have h1 : a * b ≤ 0 := Int.mul_nonpos_of_nonpos_of_nonneg (by omega) b0
      exact Int.mul_nonpos_of_nonpos_of_nonneg h1 c0
    exact Int.le_trans this (bound_nonneg N)
  · -- b,c negative, a ≥ 0
    exact two_neg_bound ha hbb hc a0 b0 c0 (by omega) (by omega) (by omega)
  · -- b negative only
    have : a * b * c ≤ 0 := by
      have h1 : a * b ≤ 0 := Int.mul_nonpos_of_nonneg_of_nonpos a0 (by omega)
      exact Int.mul_nonpos_of_nonpos_of_nonneg h1 c0
    exact Int.le_trans this (bound_nonneg N)
  · -- c negative only
    have : a * b * c ≤ 0 := Int.mul_nonpos_of_nonneg_of_nonpos (Int.mul_nonneg a0 b0) (by omega)
    exact Int.le_trans this (bound_nonneg N)
  · -- none negative
    exact all_nonneg_bound hN ha.2 hbb.2 hc.2 a0 b0 c0 (by omega)

/-- Spam attains the bound: after n clicks of `a`, the state is (2^n, 1−n, 1−n). -/
theorem spam_state : ∀ n, runFrom .nosat s1 (List.replicate n .A) = ⟨(2:Int)^n, 1 - (n:Int), 1 - (n:Int)⟩ := by
  intro n; induction n with
  | zero => decide
  | succ n ih =>
    rw [List.replicate_succ', runFrom_append, ih]
    simp only [runFrom, step, clamp, St.mk.injEq, Int.pow_succ]; push_cast; refine ⟨?_, ?_, ?_⟩ <;> omega

theorem spam_attains (n : Nat) : prod (runFrom .nosat s1 (List.replicate n .A)) = bound n := by
  rw [spam_state]; unfold prod bound; grind

end Abc
