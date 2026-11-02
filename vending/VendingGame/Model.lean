import Std

namespace VendingGame

inductive Level where
  | simple | refunds | broken | repaired
  deriving DecidableEq, BEq, Repr

inductive Node where
  | waiting | credit | dispensing | refundRequested | coinReturnedWhileDispensing
  | resolving | refundDue | refundPending | served | refunded | freeDrink
  deriving DecidableEq, BEq, Repr

inductive Actor where
  | machine | player
  deriving DecidableEq, BEq, Repr

inductive Action where
  | insertCoin | buy | askRefund | motorDelivers | motorJams
  | returnCoin | waitForMotor | coinReturned
  deriving DecidableEq, BEq, Repr

def Action.all : List Action :=
  [.insertCoin, .buy, .askRefund, .motorDelivers, .motorJams,
   .returnCoin, .waitForMotor, .coinReturned]

theorem Action.complete (a : Action) : a ∈ Action.all := by
  cases a <;> simp [Action.all]

def owner : Node → Actor
  | .refundRequested | .refundDue => .machine
  | _ => .player

def Safe (s : Node) : Prop := s ≠ .freeDrink
def Goal (s : Node) : Prop := s = .served ∨ s = .refunded
instance (s : Node) : Decidable (Safe s) := inferInstanceAs (Decidable (s ≠ .freeDrink))
instance (s : Node) : Decidable (Goal s) := by unfold Goal; infer_instance

def step (level : Level) (s : Node) (a : Action) : Option Node :=
  match s, a with
  | .waiting, .insertCoin => some .credit
  | .credit, .buy => some .dispensing
  | .credit, .askRefund => if level = .simple then none else some .refundDue
  | .dispensing, .motorDelivers => some .served
  | .dispensing, .motorJams => if level = .simple then none else some .refundDue
  | .dispensing, .askRefund =>
      if level = .broken ∨ level = .repaired then some .refundRequested else none
  | .refundRequested, .returnCoin => some .coinReturnedWhileDispensing
  | .refundRequested, .waitForMotor =>
      if level = .repaired then some .resolving else none
  | .coinReturnedWhileDispensing, .motorDelivers => some .freeDrink
  | .coinReturnedWhileDispensing, .motorJams => some .refunded
  | .resolving, .motorDelivers => some .served
  | .resolving, .motorJams => some .refundDue
  | .refundDue, .returnCoin => some .refundPending
  | .refundPending, .coinReturned => some .refunded
  | _, _ => none

def enabled (level : Level) (s : Node) : List Action :=
  Action.all.filter (fun a => (step level s a).isSome)

theorem enabled_iff (level : Level) (s : Node) (a : Action) :
    a ∈ enabled level s ↔ (step level s a).isSome = true := by
  simp [enabled, Action.complete]

theorem goals_have_no_moves (level : Level) (s : Node) (h : Goal s) :
    enabled level s = [] := by
  rcases h with h | h <;> subst s <;> simp [enabled, Action.all, step]

def replay (level : Level) : Node → List Action → Except String Node
  | s, [] => .ok s
  | s, a :: rest =>
      match step level s a with
      | none => .error "That button is not available here. The move list was rejected."
      | some t => replay level t rest

def Node.label : Node → String
  | .waiting => "You have a coin. The machine has a drink."
  | .credit => "Your coin is inside. Buy a drink or ask for it back."
  | .dispensing => "The motor is running. The drink has not dropped yet."
  | .refundRequested => "You pressed REFUND while the motor was running."
  | .coinReturnedWhileDispensing => "You got your coin back. The motor is still running…"
  | .resolving => "Refund held. The machine waits to see if the drink drops."
  | .refundDue => "No drink was delivered. The machine owes you a coin."
  | .refundPending => "The coin-return mechanism is running."
  | .served => "You got the drink. The machine kept the coin."
  | .refunded => "You got your coin back. The machine kept the drink."
  | .freeDrink => "FREE DRINK! You have the drink AND your coin."

def Node.id (s : Node) : String := (repr s).pretty |>.splitOn "." |>.getLast!

def Action.id : Action → String
  | .insertCoin => "insertCoin" | .buy => "buy" | .askRefund => "askRefund"
  | .motorDelivers => "motorDelivers" | .motorJams => "motorJams"
  | .returnCoin => "returnCoin" | .waitForMotor => "waitForMotor" | .coinReturned => "coinReturned"

def Action.label : Action → String
  | .insertCoin => "Insert your coin" | .buy => "Press BUY"
  | .askRefund => "Press REFUND" | .motorDelivers => "The drink drops"
  | .motorJams => "The motor jams" | .returnCoin => "Return the coin now"
  | .waitForMotor => "Hold refund until the motor finishes"
  | .coinReturned => "The coin drops into the return tray"

def Level.title : Level → String
  | .simple => "1. Buy a drink" | .refunds => "2. Add refunds and jams"
  | .broken => "3. Refund during dispensing — exploitable"
  | .repaired => "4. Make the machine wait — repaired"

def Node.coinWithPlayer : Node → Bool
  | .waiting | .coinReturnedWhileDispensing | .refunded | .freeDrink => true
  | _ => false

def Node.drinkWithPlayer : Node → Bool
  | .served | .freeDrink => true
  | _ => false

/-- The displayed exploit is exactly a delivered drink plus a returned coin.
    The initial unspent coin does not count because no drink has been delivered. -/
theorem safety_matches_ownership (s : Node) :
    Safe s ↔ ¬ (s.coinWithPlayer = true ∧ s.drinkWithPlayer = true) := by
  cases s <;> simp [Safe, Node.coinWithPlayer, Node.drinkWithPlayer]

end VendingGame
