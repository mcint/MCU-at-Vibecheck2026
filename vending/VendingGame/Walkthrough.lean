import VendingGame.Policy

namespace VendingGame

/- Read this file before the general checker.

   Story: insert a coin, press BUY, then press REFUND before the motor finishes.
   Bad outcome: the player receives both the drink and the returned coin.
   Repair: hold the refund until the motor either delivers or jams.
-/

-- The everyday rule and its exact representation agree for every modeled state.
example (s : Node) :
    Safe s ↔ ¬ (s.coinWithPlayer = true ∧ s.drinkWithPlayer = true) :=
  safety_matches_ownership s

-- The bad rule returns the coin while the drink can still drop.
example : replay .broken .waiting
    [.insertCoin, .buy, .askRefund, .returnCoin, .motorDelivers] = .ok .freeDrink :=
  free_drink_exploit

-- Holding the refund: a delivered drink is paid for.
theorem repair_delivered_drink : replay .repaired .waiting
    [.insertCoin, .buy, .askRefund, .waitForMotor, .motorDelivers] = .ok .served := by rfl

-- Holding the refund: a jam results in returning the coin instead.
theorem repair_jammed_motor : replay .repaired .waiting
    [.insertCoin, .buy, .askRefund, .waitForMotor, .motorJams, .returnCoin, .coinReturned] =
      .ok .refunded := by rfl

-- The actual repaired rule preserves the business promise for every reachable state.
example (s : Node) (h : PolicyReachable .repaired s) :
    ¬ (s.coinWithPlayer = true ∧ s.drinkWithPlayer = true) :=
  repaired_policy_never_gives_both s h

-- The original rule has an allowed execution that violates the same promise.
example : ∃ s, PolicyReachable .broken s ∧
    s.coinWithPlayer = true ∧ s.drinkWithPlayer = true :=
  broken_policy_violates_promise

-- Strategy existence is an additional, separate result.
example : Forces .repaired .waiting := repaired_has_strategy
example : ¬ Forces .broken .waiting := broken_no_strategy

end VendingGame
