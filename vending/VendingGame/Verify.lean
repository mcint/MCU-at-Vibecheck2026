import VendingGame.Model

namespace VendingGame

/-- Finite strategy trees: choose one machine action, cover every environment
    action, and end at a safe goal. The nonempty premise rules out vacuous wins. -/
inductive Forces (level : Level) : Node → Prop where
  | done {s} : Safe s → Goal s → Forces level s
  | machine {s a t} : Safe s → owner s = .machine →
      step level s a = some t → Forces level t → Forces level s
  | environment {s} : Safe s → owner s ≠ .machine →
      (∃ a t, step level s a = some t) →
      (∀ a t, step level s a = some t → Forces level t) → Forces level s

def wins : Nat → Level → Node → Bool
  | 0, _, s => decide (Safe s ∧ Goal s)
  | n+1, level, s =>
      decide (Safe s) && (decide (Goal s) ||
        if owner s = .machine then
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
      · by_cases ho : owner s = .machine
        · simp only [ho, ↓reduceIte, List.any_eq_true] at hb
          obtain ⟨a, _, ha⟩ := hb
          cases ht : step level s a with
          | none => simp [ht] at ha
          | some t =>
              exact .machine hs ho ht (ih t (by simpa [ht] using ha))
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
theorem simple_wins : wins 8 .simple .waiting = true := by decide
set_option maxRecDepth 4096 in
theorem refunds_wins : wins 8 .refunds .waiting = true := by decide
set_option maxRecDepth 4096 in
theorem broken_loses_within_eight : wins 8 .broken .waiting = false := by decide
set_option maxRecDepth 4096 in
theorem repaired_wins : wins 8 .repaired .waiting = true := by decide

theorem repaired_has_strategy : Forces .repaired .waiting :=
  wins_sound 8 .repaired .waiting repaired_wins

theorem Forces.safe {level s} (h : Forces level s) : Safe s := by
  cases h <;> assumption

theorem Forces.reply {level s a t} (h : Forces level s) (hg : ¬ Goal s)
    (ho : owner s ≠ .machine) (ht : step level s a = some t) : Forces level t := by
  cases h with
  | done _ hgoal => exact False.elim (hg hgoal)
  | machine _ howner _ _ => exact False.elim (ho howner)
  | environment _ _ _ hall => exact hall a t ht

theorem returned_coin_loses : ¬ Forces .broken .coinReturnedWhileDispensing := by
  intro h
  have hb := h.reply (by simp [Goal]) (by decide)
    (a := .motorDelivers) (t := .freeDrink) (by rfl)
  exact hb.safe rfl

theorem refund_request_loses : ¬ Forces .broken .refundRequested := by
  have onlyReturn : ∀ (a : Action) (t : Node),
      step .broken .refundRequested a = some t → t = .coinReturnedWhileDispensing := by
    intro a t ht
    cases a <;> simp_all [step]
  intro h
  cases h with
  | done _ hg => simp [Goal] at hg
  | environment _ ho _ _ => exact ho rfl
  | machine _ _ ht hw =>
      have he := onlyReturn _ _ ht
      rw [he] at hw
      exact returned_coin_loses hw

theorem dispensing_loses : ¬ Forces .broken .dispensing := by
  intro h
  exact refund_request_loses
    (h.reply (by simp [Goal]) (by decide) (a := .askRefund) (by rfl))

theorem credit_loses : ¬ Forces .broken .credit := by
  intro h
  exact dispensing_loses
    (h.reply (by simp [Goal]) (by decide) (a := .buy) (by rfl))

theorem broken_no_strategy : ¬ Forces .broken .waiting := by
  intro h
  exact credit_loses
    (h.reply (by simp [Goal]) (by decide) (a := .insertCoin) (by rfl))

theorem happy_purchase :
    replay .broken .waiting [.insertCoin, .buy, .motorDelivers] = .ok .served := by rfl

theorem free_drink_exploit :
    replay .broken .waiting [.insertCoin, .buy, .askRefund, .returnCoin, .motorDelivers] =
      .ok .freeDrink := by rfl

#print axioms enabled_iff
#print axioms safety_matches_ownership
#print axioms wins_sound
#print axioms repaired_has_strategy
#print axioms broken_no_strategy

end VendingGame
