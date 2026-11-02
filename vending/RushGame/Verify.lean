import RushGame.Model

namespace RushGame

def Protected (s : State) : Prop :=
  Safe s ∧ s.a ≠ .refundRunning ∧ s.b ≠ .refundRunning

instance (s : State) : Decidable (Protected s) := by unfold Protected; infer_instance

/- Exhaustive local preservation over both finite order phases and every action.
    The reachability theorem below lifts it to histories of any length. -/
set_option maxRecDepth 10000 in
set_option maxHeartbeats 4000000 in
theorem repaired_preserves (s t : State) (a : Action)
    (hs : Protected s) (ht : step .repaired s a = some t) : Protected t := by
  rcases s with ⟨left, right⟩
  cases left <;> cases right <;> cases a <;>
    simp_all [step, advance, Action.target, Action.operation,
      Protected, Safe, Order.fair, Order.claim, Order.coin, Order.drink, Order.refunds] <;>
    subst t <;> decide

theorem repaired_stays_protected (s : State) (h : Reachable .repaired s) : Protected s := by
  induction h with
  | start => decide
  | next _ ht ih => exact repaired_preserves _ _ _ ih ht

theorem repaired_all_promises (s : State) (h : Reachable .repaired s) : Safe s :=
  (repaired_stays_protected s h).1

theorem repaired_capacity (s : State) (h : Reachable .repaired s) :
    s.a.claim + s.b.claim ≤ 1 := (repaired_all_promises s h).1

theorem repaired_paid_delivery (s : State) (h : Reachable .repaired s) :
    s.a.fair ∧ s.b.fair := by
  have hs := repaired_all_promises s h
  exact ⟨hs.2.1, hs.2.2.1⟩

theorem repaired_refund_once (s : State) (h : Reachable .repaired s) :
    s.a.refunds ≤ 1 ∧ s.b.refunds ≤ 1 := by
  have hs := repaired_all_promises s h
  exact ⟨hs.2.2.2.1, hs.2.2.2.2⟩

theorem replay_reachable (policy : Policy) (moves : List Action) (s t : State)
    (hs : Reachable policy s) (h : replay policy s moves = .ok t) : Reachable policy t := by
  induction moves generalizing s with
  | nil => simp [replay] at h; subst t; exact hs
  | cons a rest ih =>
    cases ht : step policy s a with
    | none => simp [replay, ht] at h
    | some next => exact ih next (.next hs ht) (by simpa [replay, ht] using h)

theorem accepted_repaired_history_safe (moves : List Action) (s : State)
    (h : replay .repaired initial moves = .ok s) : Safe s :=
  repaired_all_promises s (replay_reachable .repaired moves initial s .start h)

def overbook : List Action := [.insertCoinA, .buyA, .insertCoinB, .buyB]
def freeDrink : List Action := [.insertCoinA, .buyA, .askRefundA, .motorDeliversA]
def duplicateRefund : List Action := [.insertCoinA, .askRefundA, .retryRefundA]

theorem old_double_books :
    replay .broken initial overbook = .ok ⟨.running, .running⟩ ∧
    ¬ Safe ⟨.running, .running⟩ := ⟨rfl, by decide⟩

theorem old_gives_free_drink :
    replay .broken initial freeDrink = .ok ⟨.freeDrink, .idle⟩ ∧
    ¬ Safe ⟨.freeDrink, .idle⟩ := ⟨rfl, by decide⟩

theorem old_pays_refund_twice :
    replay .broken initial duplicateRefund = .ok ⟨.doubleRefund, .idle⟩ ∧
    ¬ Safe ⟨.doubleRefund, .idle⟩ := ⟨rfl, by decide⟩

theorem repair_rejects_double_booking :
    replay .repaired initial overbook =
      .error "This action is not allowed for that buyer under this policy." := by rfl

theorem buy_reserves_slot (other : Order) :
    advance .repaired .credit other .buy =
      if other.claim = 0 then some .running else none := by rfl

theorem repair_holds_refund :
    replay .repaired initial freeDrink = .ok ⟨.served, .idle⟩ := by rfl

theorem repair_refund_retry_idempotent :
    replay .repaired initial duplicateRefund = .ok ⟨.refunded, .idle⟩ := by rfl

theorem jam_releases_slot_for_other_buyer :
    replay .repaired initial
      [.insertCoinA, .buyA, .insertCoinB, .askRefundA, .motorJamsA, .buyB, .motorDeliversB] =
      .ok ⟨.refunded, .served⟩ := by rfl

theorem normal_purchase_still_works :
    replay .repaired initial [.insertCoinA, .buyA, .motorDeliversA] =
      .ok ⟨.served, .idle⟩ := by rfl

#print axioms repaired_all_promises
#print axioms accepted_repaired_history_safe
#print axioms old_double_books
#print axioms old_gives_free_drink
#print axioms old_pays_refund_twice

end RushGame
