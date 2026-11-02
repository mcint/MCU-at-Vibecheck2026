import ParserDiff.Model

/-!
# Theorems about framing profiles

1. `strict_unambiguous`   — if `strict` accepts, every reading of the headers
                            yields the same body length.
2. `no_desync_strict_strict`, and much stronger `backend_strict_safe`:
   put `strict` on *either* hop and desync is impossible against *any* profile.
3. `desync_only_on_dirty`  — desync needs CL+TE or differing duplicate CLs;
   `desync_clFirst_teWins_iff`, `desync_clFirst_clLast_iff` — exact
   characterisations for two lenient pairs.
4. `refines_no_desync`, `strict_bottom` — the refinement order: `strict` is the
   bottom element, and refinement in either direction kills desync.
-/

namespace ParserDiff
open Profile

/-! ## Helper lemmas -/

theorem allEq_iff (n : Nat) (ns : List Nat) :
    allEq n ns = true ↔ ∀ x ∈ ns, x = n := by
  induction ns with
  | nil => simp [allEq]
  | cons x xs ih =>
    simp [allEq, ih]

theorem clStrict_some_cons {n : Nat} {ns : List Nat} {k : Nat}
    (h : clStrict (n :: ns) = some k) : k = n ∧ allEq n ns = true := by
  unfold clStrict at h
  by_cases ha : allEq n ns = true
  · simp [ha] at h; exact ⟨h.symm, ha⟩
  · simp [ha] at h

theorem getLast?_cons_getD (n : Nat) (ns : List Nat) :
    (n :: ns).getLast? = some (ns.getLast?.getD n) := by
  cases ns with
  | nil => rfl
  | cons x xs =>
    cases h : (x :: xs).getLast? with
    | none => simp at h
    | some y => rw [List.getLast?_cons_cons, h]; rfl

/-! ## (1) strict is unambiguous -/

/-- Every profile picks a body length that *some* reading of the headers
    justifies.  (No profile invents a length.) -/
theorem frame_mem_readings (p : Profile) (m : Msg) (k : Nat)
    (h : frame p m = some k) : k ∈ readings m := by
  obtain ⟨cls, te, cl⟩ := m
  cases p <;> cases te <;> cases cls with
  | nil => simp_all [frame, readings, clStrict]
  | cons n ns =>
    all_goals simp [frame, readings] at h ⊢
    all_goals first
      | (obtain ⟨rfl, -⟩ := clStrict_some_cons h; simp)
      | (subst h; simp)
      | (subst h
         cases hl : ns.getLast? with
         | none => simp
         | some y => have := List.mem_of_getLast? hl; simp [this])

/-- **Theorem (1).**  If `strict` accepts a message with body length `k`,
    then *every* reading of its headers gives `k`: there is nothing for a
    second parser to disagree about. -/
theorem strict_unambiguous (m : Msg) (k : Nat)
    (h : frame strict m = some k) : ∀ r ∈ readings m, r = k := by
  obtain ⟨cls, te, cl⟩ := m
  intro r hr
  cases te with
  | true => cases cls <;> simp_all [frame, readings]
  | false =>
  cases cls with
  | nil => simp_all [frame, readings, clStrict]
  | cons n ns =>
    simp [frame] at h
    obtain ⟨rfl, ha⟩ := clStrict_some_cons h
    have hall := (allEq_iff _ _).1 ha
    simp [readings] at hr
    rcases hr with rfl | hr
    · rfl
    · exact hall r hr

/-- If `strict` accepts, every other profile accepts too. -/
theorem strict_accepts_all (p : Profile) (m : Msg) (k : Nat)
    (h : frame strict m = some k) : accepts p m := by
  obtain ⟨cls, te, cl⟩ := m
  unfold accepts
  cases p <;> cases te <;> cases cls with
  | nil => simp_all [frame, clStrict]
  | cons n ns =>
    all_goals simp [frame] at h ⊢
    all_goals first
      | exact absurd h (by simp)
      | (obtain ⟨rfl, ha⟩ := clStrict_some_cons h; simp [clStrict, ha])
      | trivial

/-- If `strict` accepts with length `k`, any profile that accepts agrees on `k`. -/
theorem strict_agree (p : Profile) (m : Msg) (k k' : Nat)
    (hs : frame strict m = some k) (hp : frame p m = some k') : k' = k :=
  strict_unambiguous m k hs k' (frame_mem_readings p m k' hp)

/-! ## (4) refinement order -/

/-- `strict` is the bottom of the refinement order: it refines everything. -/
theorem strict_bottom (p : Profile) : refines strict p := by
  intro m k h
  have ha := strict_accepts_all p m k h
  unfold accepts at ha
  cases hp : frame p m with
  | none => simp [hp] at ha
  | some k' => rw [strict_agree p m k k' h hp]

/-- **Theorem (4).**  If the back end refines the front end (accepts a subset,
    and agrees whenever it accepts) there is no desync in either direction:
    whatever the front end lets through is either rejected by the back end
    (safe: the connection is torn down) or framed identically. -/
theorem refines_no_desync (B F : Profile) (hr : refines B F) (m : Msg) :
    ¬ desync F B m ∧ ¬ desync B F m := by
  constructor
  · rintro ⟨hne, -, hb⟩
    unfold accepts at hb
    cases hb' : frame B m with
    | none => simp [hb'] at hb
    | some n => exact hne (by rw [hr m n hb', hb'])
  · rintro ⟨hne, hb, -⟩
    unfold accepts at hb
    cases hb' : frame B m with
    | none => simp [hb'] at hb
    | some n => exact hne (by rw [hr m n hb', hb'])

/-! ## (2) no desync with strict anywhere -/

/-- **Theorem (2).** Two strict parsers never desync. -/
theorem no_desync_strict_strict : ∀ m, ¬ desync strict strict m := by
  rintro m ⟨hne, -, -⟩
  exact hne rfl

/-- **Make the back end strict and smuggling is impossible**, for *any*
    front end. -/
theorem backend_strict_safe : ∀ (F : Profile) (m : Msg), ¬ desync F strict m :=
  fun F m => (refines_no_desync strict F (strict_bottom F) m).1

/-- Symmetric: a strict front end also kills desync against any back end. -/
theorem frontend_strict_safe : ∀ (B : Profile) (m : Msg), ¬ desync strict B m :=
  fun B m => (refines_no_desync strict B (strict_bottom B) m).2

/-- A profile refines `strict` only if it *is* `strict`, i.e. a lenient
    profile accepts strictly more.  (Witness: `⟨[1], true, 2⟩`.) -/
theorem refines_strict_iff (p : Profile) : refines p strict ↔ p = strict := by
  constructor
  · intro h
    cases p with
    | strict => rfl
    | teWins  => exact absurd (h ⟨[1], true, 2⟩ 2 rfl) (by decide)
    | clFirst => exact absurd (h ⟨[1], true, 2⟩ 1 rfl) (by decide)
    | clLast  => exact absurd (h ⟨[1], true, 2⟩ 1 rfl) (by decide)
  · rintro rfl; exact fun m n h => h

/-! ## (3) where desync can live -/

/-- A clean message is accepted by `strict`. -/
theorem clean_accepts_strict (m : Msg) (hc : clean m) : ∃ k, frame strict m = some k := by
  obtain ⟨cls, te, cl⟩ := m
  obtain ⟨h1, h2⟩ := hc
  cases te with
  | true =>
    rcases h1 with h | h
    · cases h
    · simp at h; subst h; exact ⟨cl, rfl⟩
  | false =>
    cases cls with
    | nil => exact ⟨0, rfl⟩
    | cons n ns =>
      refine ⟨n, ?_⟩
      have ha : allEq n ns = true :=
        (allEq_iff n ns).2 fun x hx =>
          h2 x (List.mem_cons_of_mem n hx) n List.mem_cons_self
      simp [frame, clStrict, ha]

/-- **Theorem (3a).**  Desync between *any* two profiles requires a dirty
    message: both CL and TE present, or duplicate Content-Lengths that differ. -/
theorem desync_only_on_dirty (F B : Profile) (m : Msg)
    (hd : desync F B m) : ¬ clean m := by
  intro hc
  obtain ⟨k, hk⟩ := clean_accepts_strict m hc
  obtain ⟨hne, hf, hb⟩ := hd
  unfold accepts at hf hb
  cases hf' : frame F m with
  | none => simp [hf'] at hf
  | some a =>
    cases hb' : frame B m with
    | none => simp [hb'] at hb
    | some b =>
      have := strict_agree F m k a hk hf'
      have := strict_agree B m k b hk hb'
      subst_vars
      exact hne (by rw [hf', hb'])

/-- Contrapositive, in the form the demo quotes. -/
theorem clean_no_desync (m : Msg) (hc : clean m) : ∀ F B, ¬ desync F B m :=
  fun F B hd => desync_only_on_dirty F B m hd hc

/-- **Theorem (3b).**  CL.TE exactly: a `clFirst` front end and a
    TE-honouring back end desync precisely when TE is present, a
    Content-Length is present, and the first CL differs from the chunked length. -/
theorem desync_clFirst_teWins_iff (m : Msg) :
    desync clFirst teWins m ↔
      m.te = true ∧ ∃ n ns, m.cls = n :: ns ∧ n ≠ m.chunkedLen := by
  obtain ⟨cls, te, cl⟩ := m
  cases te with
  | true => cases cls <;> simp [desync, accepts, frame]
  | false =>
  cases cls with
  | nil => simp [desync, accepts, frame, clStrict]
  | cons n ns =>
    -- both use Content-Length; teWins may reject but cannot differ
    simp [desync, accepts, frame]
    intro hne
    cases h : clStrict (n :: ns) with
    | none => rfl
    | some k =>
      obtain ⟨rfl, -⟩ := clStrict_some_cons h
      rw [h] at hne
      exact absurd rfl hne

/-- **Theorem (3c).**  Duplicate-CL exactly: `clFirst` vs `clLast` desync
    precisely when the first and last Content-Length differ. -/
theorem desync_clFirst_clLast_iff (m : Msg) :
    desync clFirst clLast m ↔ m.cls.head? ≠ m.cls.getLast? := by
  obtain ⟨cls, te, cl⟩ := m
  cases cls with
  | nil => simp [desync, accepts, frame]
  | cons n ns =>
    simp [desync, accepts, frame, getLast?_cons_getD]

end ParserDiff
