import VendingGame.Policy

namespace VendingGame

/-- Business rule 1: starting a purchase requires accepted credit. -/
theorem buy_requires_credit (level : Level) (s t : Node)
    (h : step level s .buy = some t) : s = .credit ∧ t = .dispensing := by
  cases s <;> simp_all [step]

/-- Business rule 2: before buying, the repaired policy returns the coin. -/
theorem refund_before_buying :
    replay .repaired .credit [.askRefund, .returnCoin, .coinReturned] = .ok .refunded := by rfl

/-- Business rule 3: successful delivery settles without returning payment. -/
theorem delivery_keeps_payment :
    policyStep .repaired .resolving .motorDelivers = some .served ∧
      Node.served.drinkWithPlayer = true ∧ Node.served.coinWithPlayer = false := by
  exact ⟨rfl, rfl, rfl⟩

/-- Business rule 4: a failed delivery follows the refund path. -/
theorem failed_delivery_refunds :
    replay .repaired .resolving [.motorJams, .returnCoin, .coinReturned] = .ok .refunded := by rfl

/-- Business rule 5: the specific repaired machine rule waits for the motor. -/
theorem hold_refund_while_delivering :
    machineChoice .repaired .refundRequested = .waitForMotor := by rfl

/-- The old behavior is represented explicitly, rather than described as repaired. -/
theorem old_rule_returns_immediately :
    machineChoice .broken .refundRequested = .returnCoin := by rfl

end VendingGame
