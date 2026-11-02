import RushGame.Verify

namespace RushGame

/-- The three old-rule failures are executable, checked witnesses. -/
example : replay .broken initial overbook = .ok ⟨.running, .running⟩ ∧
    ¬ Safe ⟨.running, .running⟩ := old_double_books

example : replay .broken initial freeDrink = .ok ⟨.freeDrink, .idle⟩ ∧
    ¬ Safe ⟨.freeDrink, .idle⟩ := old_gives_free_drink

example : replay .broken initial duplicateRefund = .ok ⟨.doubleRefund, .idle⟩ ∧
    ¬ Safe ⟨.doubleRefund, .idle⟩ := old_pays_refund_twice

/-- Looking safe right now is insufficient: a refunded running motor can deliver.
    This phase is excluded by the stronger repaired reachability invariant. -/
example : Safe ⟨.refundRunning, .idle⟩ := by decide
example : ¬ Protected ⟨.refundRunning, .idle⟩ := by decide

/-- Every repaired execution preserves capacity, paid delivery, and refund-once. -/
example (s : State) (h : Reachable .repaired s) :
    s.a.claim + s.b.claim ≤ 1 ∧
    s.a.fair ∧ s.b.fair ∧ s.a.refunds ≤ 1 ∧ s.b.refunds ≤ 1 :=
  repaired_all_promises s h

/-- The machine still sells drinks and releases a jammed reservation. -/
example : replay .repaired initial
    [.insertCoinA, .buyA, .insertCoinB, .askRefundA, .motorJamsA, .buyB, .motorDeliversB] =
    .ok ⟨.refunded, .served⟩ := jam_releases_slot_for_other_buyer

end RushGame
