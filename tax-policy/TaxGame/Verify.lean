import TaxGame.Model

namespace TaxGame

theorem net_monotone (a b : Nat) (h : a ≤ b) : net a ≤ net b := by
  unfold net tax
  omega

theorem repaired_floor (wages side : Nat) : 1200 ≤ resources .repaired wages side := by
  simp only [resources, support]
  omega

theorem repaired_support_bounded (wages side : Nat) : support .repaired wages side ≤ 1200 := by
  simp only [support]
  omega

theorem repaired_monotone (w₁ s₁ w₂ s₂ : Nat) (h : w₁ + s₁ ≤ w₂ + s₂) :
    resources .repaired w₁ s₁ ≤ resources .repaired w₂ s₂ := by
  have hn := net_monotone _ _ h
  simp only [resources, support]
  omega

theorem repaired_source_neutral (w₁ s₁ w₂ s₂ : Nat) (h : w₁ + s₁ = w₂ + s₂) :
    resources .repaired w₁ s₁ = resources .repaired w₂ s₂ := by
  simp only [resources, support]
  rw [h]

/-- Assessment is fixed after the first filing; retries cannot change its payout. -/
def Protected (s : State) : Prop :=
  s.noCliff = true ∧ s.fairSources = true ∧
  (s.claimed = false → s.paid = 0 ∧ s.payments = 0) ∧
  (s.claimed = true → s.paid = support .repaired s.wages s.side ∧ s.payments = 1)

theorem initial_protected (wages side : Nat) : Protected (initial wages side) := by
  simp [Protected, initial]

theorem raised_protected (s : State) (amount : Nat) (hs : Protected s) (hc : s.claimed = false) :
    Protected (raised .repaired s amount) := by
  have hm := repaired_monotone s.wages s.side (s.wages + amount) s.side (by omega)
  simp_all [raised, Protected]

theorem shifted_protected (s : State) (hs : Protected s) (hc : s.claimed = false)
    (hw : 100 ≤ s.wages) : Protected (shifted .repaired s) := by
  have he := repaired_source_neutral s.wages s.side (s.wages - 100) (s.side + 100) (by omega)
  simp_all [shifted, Protected]

theorem filed_protected (s : State) (hs : Protected s) : Protected (filed .repaired s) := by
  cases hc : s.claimed <;> simp_all [filed, Protected]

theorem repaired_preserves (s t : State) (a : Action) (hs : Protected s)
    (ht : step .repaired s a = some t) : Protected t := by
  cases hc : s.claimed <;> cases a <;> simp [step, hc] at ht
  all_goals first
    | (subst t; exact raised_protected s _ hs hc)
    | (subst t; exact filed_protected s hs)
    | (rcases ht with ⟨hw, rfl⟩; exact shifted_protected s hs hc hw)

theorem repaired_stays_protected (wages side : Nat) (s : State)
    (h : Reachable .repaired wages side s) : Protected s := by
  induction h with
  | start => exact initial_protected _ _
  | next _ ht ih => exact repaired_preserves _ _ _ ih ht

theorem protected_safe (s : State) (h : Protected s) : Safe .repaired s := by
  have hb := repaired_support_bounded s.wages s.side
  have hf := repaired_floor s.wages s.side
  cases hc : s.claimed <;> simp_all [Protected, Safe]

theorem repaired_all_promises (wages side : Nat) (s : State)
    (h : Reachable .repaired wages side s) : Safe .repaired s :=
  protected_safe s (repaired_stays_protected wages side s h)

theorem replay_reachable (p : Policy) (wages side : Nat) (moves : List Action) (s t : State)
    (hs : Reachable p wages side s) (h : replay p s moves = .ok t) : Reachable p wages side t := by
  induction moves generalizing s with
  | nil => simp [replay] at h; subst t; exact hs
  | cons a rest ih =>
    cases ht : step p s a with
    | none => simp [replay, ht] at h
    | some next => exact ih next (.next hs ht) (by simpa [replay, ht] using h)

theorem accepted_repaired_history_safe (wages side : Nat) (moves : List Action) (s : State)
    (h : replay .repaired (initial wages side) moves = .ok s) : Safe .repaired s :=
  repaired_all_promises wages side s (replay_reachable .repaired wages side moves _ s .start h)

theorem old_one_dollar_cliff : resources .broken 1199 0 = 1480 ∧
    resources .broken 1200 0 = 1080 := by decide

theorem old_source_loophole : resources .broken 1000 0 = 1300 ∧
    resources .broken 900 100 = 1900 := by decide

theorem old_duplicate_payout :
    replay .broken (initial 999 0) [.file, .retry] =
      .ok ⟨999, 0, 2000, 2, true, true, true⟩ := by rfl

theorem repaired_retry_idempotent (s : State) (hc : s.claimed = true) :
    step .repaired s .retry = some s := by simp [step, filed, hc]

#print axioms repaired_floor
#print axioms repaired_monotone
#print axioms repaired_all_promises
#print axioms accepted_repaired_history_safe

end TaxGame
