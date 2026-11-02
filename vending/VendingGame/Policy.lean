import VendingGame.Verify

namespace VendingGame

/-- The business rule the frontend's machine actually follows. -/
def machineChoice (level : Level) (s : Node) : Action :=
  if level = .repaired ∧ s = .refundRequested then .waitForMotor else .returnCoin

def policyStep (level : Level) (s : Node) (a : Action) : Option Node :=
  if owner s = .machine then
    if a = machineChoice level s then step level s a else none
  else step level s a

def policyReplay (level : Level) : Node → List Action → Except String Node
  | s, [] => .ok s
  | s, a :: rest =>
      match policyStep level s a with
      | none => .error "The machine policy does not allow that action. The move list was rejected."
      | some t => policyReplay level t rest

/-- States reached by following the chosen machine rule. Player and motor replies
    remain unrestricted wherever the original model enables them. -/
inductive PolicyReachable (level : Level) : Node → Prop where
  | start : PolicyReachable level .waiting
  | next {s a t} : PolicyReachable level s → policyStep level s a = some t →
      PolicyReachable level t

def RefundProtected (s : Node) : Prop :=
  s ≠ .coinReturnedWhileDispensing ∧ s ≠ .freeDrink

instance (s : Node) : Decidable (RefundProtected s) := by
  unfold RefundProtected
  infer_instance

theorem repair_preserves_refund_protection (s : Node) (a : Action) (t : Node)
    (hs : RefundProtected s) (ht : policyStep .repaired s a = some t) :
    RefundProtected t := by
  cases s <;> cases a <;>
    simp_all [RefundProtected, policyStep, machineChoice, owner, step] <;>
    subst t <;> decide

theorem repaired_policy_never_gives_both (s : Node)
    (h : PolicyReachable .repaired s) :
    ¬ (s.coinWithPlayer = true ∧ s.drinkWithPlayer = true) := by
  have hprotected : RefundProtected s := by
    induction h with
    | start => simp [RefundProtected]
    | next _ ht ih => exact repair_preserves_refund_protection _ _ _ ih ht
  exact (safety_matches_ownership s).mp hprotected.2

/-- The policy replay used by the HTTP API produces only states covered by the
    reachability theorem, for every accepted history length. -/
theorem policyReplay_reachable (level : Level) (moves : List Action) (s t : Node)
    (hs : PolicyReachable level s) (h : policyReplay level s moves = .ok t) :
    PolicyReachable level t := by
  induction moves generalizing s with
  | nil =>
      simp [policyReplay] at h
      subst t
      exact hs
  | cons a rest ih =>
      cases ht : policyStep level s a with
      | none => simp [policyReplay, ht] at h
      | some next =>
          exact ih next (.next hs ht) (by simpa [policyReplay, ht] using h)

theorem accepted_repaired_history_safe (moves : List Action) (s : Node)
    (h : policyReplay .repaired .waiting moves = .ok s) :
    ¬ (s.coinWithPlayer = true ∧ s.drinkWithPlayer = true) :=
  repaired_policy_never_gives_both s
    (policyReplay_reachable .repaired moves .waiting s .start h)

theorem broken_policy_reaches_free_drink : PolicyReachable .broken .freeDrink := by
  have h1 : PolicyReachable .broken .credit :=
    .next (a := .insertCoin) .start (by rfl)
  have h2 : PolicyReachable .broken .dispensing :=
    .next (a := .buy) h1 (by rfl)
  have h3 : PolicyReachable .broken .refundRequested :=
    .next (a := .askRefund) h2 (by rfl)
  have h4 : PolicyReachable .broken .coinReturnedWhileDispensing :=
    .next (a := .returnCoin) h3 (by rfl)
  exact .next (a := .motorDelivers) h4 (by rfl)

theorem broken_policy_violates_promise :
    ∃ s, PolicyReachable .broken s ∧
      s.coinWithPlayer = true ∧ s.drinkWithPlayer = true :=
  ⟨.freeDrink, broken_policy_reaches_free_drink, rfl, rfl⟩

/-- Find a counterexample by following the machine rule and exploring every
    listed player/dispenser reply. The UI replays this result through Lean. -/
def findFailure : Nat → Level → Node → Option (List Action)
  | 0, _, s => if decide (Safe s) then none else some []
  | n+1, level, s =>
      if !decide (Safe s) then some [] else
        Action.all.findSome? fun a =>
          match policyStep level s a with
          | none => none
          | some t => (findFailure n level t).map (a :: ·)

set_option maxRecDepth 4096 in
theorem checker_finds_old_policy_failure :
    findFailure 8 .broken .waiting =
      some [.insertCoin, .buy, .askRefund, .returnCoin, .motorDelivers] := by decide

set_option maxRecDepth 4096 in
theorem checker_finds_no_repaired_failure_within_eight :
    findFailure 8 .repaired .waiting = none := by decide

theorem repaired_policy_rejects_early_refund :
    policyStep .repaired .refundRequested .returnCoin = none := by rfl

theorem broken_policy_allows_early_refund :
    policyStep .broken .refundRequested .returnCoin = some .coinReturnedWhileDispensing := by rfl

#print axioms repaired_policy_never_gives_both
#print axioms broken_policy_violates_promise
#print axioms accepted_repaired_history_safe

end VendingGame
