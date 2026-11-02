import OrderGame.Model

namespace OrderGame

/-- Finite strategy trees: choose one merchant action, cover every environment
    action, and end at a safe goal. The nonempty premise rules out vacuous wins. -/
inductive Forces (level : Level) : Node → Prop where
  | done {s} : Safe s → Goal s → Forces level s
  | merchant {s a t} : Safe s → owner s = .merchant →
      step level s a = some t → Forces level t → Forces level s
  | environment {s} : Safe s → owner s ≠ .merchant →
      (∃ a t, step level s a = some t) →
      (∀ a t, step level s a = some t → Forces level t) → Forces level s

def wins : Nat → Level → Node → Bool
  | 0, _, s => decide (Safe s ∧ Goal s)
  | n+1, level, s =>
      decide (Safe s) && (decide (Goal s) ||
        if owner s = .merchant then
          Action.all.any (fun a => match step level s a with
            | none => false
            | some t => wins n level t)
        else
          !(enabled level s).isEmpty &&
          Action.all.all (fun a => match step level s a with
            | none => true
            | some t => wins n level t))

theorem wins_sound (n : Nat) (level : Level) (s : Node)
    (h : wins n level s = true) : Forces level s := by
  induction n generalizing s with
  | zero =>
      have hs : Safe s ∧ Goal s := by simpa [wins] using h
      exact .done hs.1 hs.2
  | succ n ih =>
      have hh := h
      simp only [wins, Bool.and_eq_true, Bool.or_eq_true, decide_eq_true_eq] at hh
      obtain ⟨hs, hg | hb⟩ := hh
      · exact .done hs hg
      · by_cases ho : owner s = .merchant
        · simp only [ho, ↓reduceIte, List.any_eq_true] at hb
          obtain ⟨a, _, ha⟩ := hb
          cases ht : step level s a with
          | none => simp [ht] at ha
          | some t =>
              exact .merchant hs ho ht (ih t (by simpa [ht] using ha))
        · simp only [ho, ↓reduceIte, Bool.and_eq_true,
              List.all_eq_true] at hb
          have hex : ∃ a t, step level s a = some t := by
            have hn := hb.1
            cases he : enabled level s with
            | nil => simp [he] at hn
            | cons a rest =>
                have hm : a ∈ enabled level s := by simp [he]
                have hp := (enabled_iff level s a).mp hm
                cases ht : step level s a with
                | none => simp [ht] at hp
                | some t => exact ⟨a, t, ht⟩
          apply Forces.environment hs ho hex
          intro a t ht
          have hw := hb.2 a (Action.complete a)
          exact ih t (by simpa [ht] using hw)

set_option maxRecDepth 4096 in
theorem simple_wins : wins 8 .simple .checkout = true := by decide
set_option maxRecDepth 4096 in
theorem cancellation_wins : wins 8 .cancellation .checkout = true := by decide
set_option maxRecDepth 4096 in
theorem broken_loses_within_eight : wins 8 .broken .checkout = false := by decide
set_option maxRecDepth 4096 in
theorem repaired_wins : wins 8 .repaired .checkout = true := by decide

theorem repaired_has_strategy : Forces .repaired .checkout :=
  wins_sound 8 .repaired .checkout repaired_wins

theorem Forces.safe {level s} (h : Forces level s) : Safe s := by
  cases h <;> assumption

theorem Forces.reply {level s a t} (h : Forces level s) (hg : ¬ Goal s)
    (ho : owner s ≠ .merchant) (ht : step level s a = some t) : Forces level t := by
  cases h with
  | done _ hgoal => exact False.elim (hg hgoal)
  | merchant _ howner _ _ => exact False.elim (ho howner)
  | environment _ _ _ hall => exact hall a t ht

theorem closed_cancellation_loses : ¬ Forces .broken .closedPending := by
  intro h
  have hb := h.reply (by simp [Goal]) (by decide)
    (a := .capture) (t := .chargedAfterClose) (by rfl)
  exact hb.safe rfl

theorem broken_cancel_loses : ¬ Forces .broken .cancellationRequested := by
  have onlyClosed : ∀ (a : Action) (t : Node),
      step .broken .cancellationRequested a = some t → t = .closedPending := by
    intro a t ht
    cases a <;> simp_all [step]
  intro h
  cases h with
  | done _ hg => simp [Goal] at hg
  | environment _ ho _ _ => exact ho rfl
  | merchant _ _ ht hw =>
      have he := onlyClosed _ _ ht
      rw [he] at hw
      exact closed_cancellation_loses hw

theorem broken_pending_loses : ¬ Forces .broken .pending := by
  intro h
  exact broken_cancel_loses
    (h.reply (by simp [Goal]) (by decide) (a := .requestCancellation) (by rfl))

/-- No strategy exists in this finite model, independent of a search horizon. -/
theorem broken_no_strategy : ¬ Forces .broken .checkout := by
  intro h
  exact broken_pending_loses
    (h.reply (by simp [Goal]) (by decide) (a := .pay) (by rfl))

/-- A successful sample line does not make the broken level a winning game. -/
theorem broken_has_happy_trace :
    replay .broken .checkout [.pay, .capture, .ship] = .ok .shipped := by rfl

theorem broken_has_counterexample :
    replay .broken .checkout
      [.pay, .requestCancellation, .closeCancellation, .capture] =
      .ok .chargedAfterClose := by rfl

#print axioms enabled_iff
#print axioms wins_sound
#print axioms repaired_has_strategy
#print axioms broken_loses_within_eight
#print axioms broken_no_strategy

end OrderGame
