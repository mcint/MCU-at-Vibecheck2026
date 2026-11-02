import Abc
import Optimal
/-! # Perturbed problems: what survives, what flips (steward 2026-11-01)
1. Monotone transforms of the product (sqrt, log) — optimum unchanged, generically.
2. Fewer / more numbers — the sign-parity trick flips the answer at even dimension.
3. Sum objective in abc (floor) — spam again. -/
namespace Abc

/-! ## 1. Monotone transform: free corollary of `spam_optimal` -/
/-- Any monotone rescoring f (e.g. sqrt, log on the positive range) has the same optimum. -/
theorem spam_optimal_mono (f : Int → Int) (hf : ∀ x y, x ≤ y → f x ≤ f y)
    (p : List Act) (hN : 2 ≤ p.length) :
    f (prod (runFrom .nosat s1 p)) ≤ f (prod (runFrom .nosat s1 (List.replicate p.length .A))) := by
  rw [spam_attains]; exact hf _ _ (spam_optimal p hN)

/-! ## 2. Two numbers: spam's product is negative; the optimum dips first -/
structure St2 where
  a : Int
  b : Int
deriving Repr, DecidableEq
inductive Act2 | A | B
deriving Repr, DecidableEq

def step2 (s : St2) : Act2 → St2
  | .A => ⟨2 * s.a, s.b - 1⟩
  | .B => ⟨s.a - 1, 2 * s.b⟩
def run2 (s : St2) : List Act2 → St2
  | [] => s
  | x :: r => run2 (step2 s x) r
def prod2 (s : St2) : Int := s.a * s.b
def best2 : St2 → Nat → Int
  | s, 0 => prod2 s
  | s, t + 1 => max (best2 (step2 s .A) t) (best2 (step2 s .B) t)
def o2 : St2 := ⟨1, 1⟩

theorem le_best2 : ∀ (p : List Act2) (s : St2), prod2 (run2 s p) ≤ best2 s p.length := by
  intro p; induction p with
  | nil => intro s; simp [run2, best2]
  | cons x r ih =>
    intro s; simp only [run2, List.length_cons, best2]
    cases x with
    | A => have := ih (step2 s .A); omega
    | B => have := ih (step2 s .B); omega

/-- spam in 2D: state (2^n, 1−n) — one negative, so the product is ≤ 0 for n ≥ 1. -/
theorem spam2_state : ∀ n, run2 o2 (List.replicate n .A) = ⟨(2:Int)^n, 1 - (n:Int)⟩ := by
  intro n; induction n with
  | zero => decide
  | succ n ih =>
    rw [List.replicate_succ']
    have : ∀ s (p q : List Act2), run2 s (p ++ q) = run2 (run2 s p) q := by
      intro s p q; induction p generalizing s with
      | nil => rfl
      | cons x r ih => simp [run2, ih]
    rw [this, ih]; simp only [run2, step2, St2.mk.injEq, Int.pow_succ]; push_cast; omega

theorem spam2_nonpos (n : Nat) (hn : 1 ≤ n) : prod2 (run2 o2 (List.replicate n .A)) ≤ 0 := by
  rw [spam2_state]; simp only [prod2]
  have := hi_pos n; unfold hi at this
  exact Int.mul_nonpos_of_nonneg_of_nonpos (by omega) (by omega)

/-- The 2D optimum at N=8 is 128 (both negative: dip `a` to −1 by clicking `b` twice, then double `a`). -/
theorem par2_8 : best2 o2 8 = 128 := by decide
theorem par2_8_tight : run2 o2 [.B, .B, .A, .A, .A, .A, .A, .A] = ⟨-64, -2⟩ := by decide
theorem par2_8_bound : ∀ p : List Act2, p.length = 8 → prod2 (run2 o2 p) ≤ 128 := by
  intro p h; have := le_best2 p o2; rw [h, par2_8] at this; exact this
/-- …which is far below the 3D-style box bound 2^8·(8/2−1)² = 2304: in 2D the box is loose. -/
theorem box_loose_2d : best2 o2 8 < (2:Int)^8 * 3 * 3 := by decide

/-! ## 3. Sum objective in abc (floor): spam again, (0,0,256) at N=6 from (4,4,4). -/
def sumv (s : St) : Int := s.a + s.b + s.c
def bestSum (v : Variant) : St → Nat → Int
  | s, 0 => sumv s
  | s, t + 1 => max (bestSum v (step v s .A) t) (max (bestSum v (step v s .B) t) (bestSum v (step v s .C) t))
theorem sumPar6 : bestSum .sat s4 6 = 256 := by decide
theorem sumPar6_tight : sumv (runFrom .sat s4 (List.replicate 6 .C)) = 256 := by decide

end Abc
