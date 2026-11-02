import Std

namespace RushGame

inductive Policy where
  | broken | repaired
  deriving DecidableEq, BEq, Repr

/-- `doubleRefund` abstracts two or more refund payouts, already a violation. -/
inductive Order where
  | idle | credit | running | resolving | refundRunning
  | served | refunded | doubleRefund | freeDrink
  deriving DecidableEq, BEq, Repr

structure State where
  a : Order
  b : Order
  deriving DecidableEq, BEq, Repr

inductive Operation where
  | insertCoin | buy | askRefund | motorDelivers | motorJams | retryRefund
  deriving DecidableEq, BEq, Repr

inductive Action where
  | insertCoinA | buyA | askRefundA | motorDeliversA | motorJamsA | retryRefundA
  | insertCoinB | buyB | askRefundB | motorDeliversB | motorJamsB | retryRefundB
  deriving DecidableEq, BEq, Repr

def initial : State := ⟨.idle, .idle⟩

def Order.claim : Order → Nat
  | .running | .resolving | .refundRunning | .served | .freeDrink => 1
  | _ => 0

def Order.coin : Order → Nat
  | .idle | .refundRunning | .refunded | .freeDrink => 1
  | .doubleRefund => 2
  | _ => 0

def Order.drink : Order → Bool
  | .served | .freeDrink => true
  | _ => false

def Order.refunds : Order → Nat
  | .refundRunning | .refunded | .freeDrink => 1
  | .doubleRefund => 2
  | _ => 0

def Order.fair (o : Order) : Prop := ¬ (o.coin > 0 ∧ o.drink = true)

instance (o : Order) : Decidable (o.fair) := by unfold Order.fair; infer_instance

def Safe (s : State) : Prop :=
  s.a.claim + s.b.claim ≤ 1 ∧
  s.a.fair ∧ s.b.fair ∧ s.a.refunds ≤ 1 ∧ s.b.refunds ≤ 1

instance (s : State) : Decidable (Safe s) := by unfold Safe Order.fair; infer_instance

/-- A claim reserves the last delivery slot before any physical delivery.
    A jam releases it. A fulfilled delivery consumes it permanently. -/
def advance (policy : Policy) (own other : Order) (op : Operation) : Option Order :=
  match own, op with
  | .idle, .insertCoin => some .credit
  | .credit, .buy =>
      if policy = .repaired then
        if other.claim = 0 then some .running else none
      else if other.drink then none else some .running
  | .credit, .askRefund => some .refunded
  | .running, .askRefund =>
      some (if policy = .repaired then .resolving else .refundRunning)
  | .running, .motorDelivers => some .served
  | .running, .motorJams => some .refunded
  | .resolving, .motorDelivers => some .served
  | .resolving, .motorJams => some .refunded
  | .refundRunning, .motorDelivers => some .freeDrink
  | .refundRunning, .motorJams => some .refunded
  | .refunded, .retryRefund =>
      some (if policy = .repaired then .refunded else .doubleRefund)
  | .doubleRefund, .retryRefund => some .doubleRefund
  | _, _ => none

def Action.target : Action → Bool
  | .insertCoinA | .buyA | .askRefundA | .motorDeliversA | .motorJamsA | .retryRefundA => false
  | _ => true

def Action.operation : Action → Operation
  | .insertCoinA | .insertCoinB => .insertCoin
  | .buyA | .buyB => .buy
  | .askRefundA | .askRefundB => .askRefund
  | .motorDeliversA | .motorDeliversB => .motorDelivers
  | .motorJamsA | .motorJamsB => .motorJams
  | .retryRefundA | .retryRefundB => .retryRefund

def step (policy : Policy) (s : State) (action : Action) : Option State :=
  if action.target then
    (advance policy s.b s.a action.operation).map (fun next => ⟨s.a, next⟩)
  else (advance policy s.a s.b action.operation).map (fun next => ⟨next, s.b⟩)

def Action.all : List Action :=
  [.insertCoinA, .buyA, .askRefundA, .motorDeliversA, .motorJamsA, .retryRefundA,
   .insertCoinB, .buyB, .askRefundB, .motorDeliversB, .motorJamsB, .retryRefundB]

theorem Action.complete (a : Action) : a ∈ Action.all := by cases a <;> simp [Action.all]

def enabled (policy : Policy) (s : State) : List Action :=
  Action.all.filter (fun a => (step policy s a).isSome)

theorem enabled_iff (policy : Policy) (s : State) (a : Action) :
    a ∈ enabled policy s ↔ (step policy s a).isSome = true := by
  simp [enabled, Action.complete]

def replay (policy : Policy) : State → List Action → Except String State
  | s, [] => .ok s
  | s, a :: rest =>
      match step policy s a with
      | none => .error "This action is not allowed for that buyer under this policy."
      | some next => replay policy next rest

inductive Reachable (policy : Policy) : State → Prop where
  | start : Reachable policy initial
  | next {s a t} : Reachable policy s → step policy s a = some t → Reachable policy t

def Order.id (o : Order) : String := (repr o).pretty |>.splitOn "." |>.getLast!
def Action.id (a : Action) : String := (repr a).pretty |>.splitOn "." |>.getLast!
def State.formal (s : State) : String := s!"⟨.{s.a.id}, .{s.b.id}⟩"
def State.id (s : State) : String := s!"{s.a.id}__{s.b.id}"

def Order.label : Order → String
  | .idle => "Ready with one coin"
  | .credit => "Coin accepted"
  | .running => "Delivery slot claimed; motor running"
  | .resolving => "Refund held; waiting for motor"
  | .refundRunning => "Coin refunded; motor still running"
  | .served => "Drink delivered; payment kept"
  | .refunded => "Coin refunded; no drink"
  | .doubleRefund => "Refund paid twice"
  | .freeDrink => "Drink delivered after refund"

def Action.label (a : Action) : String :=
  let who := if a.target then "B" else "A"
  let what := match a.operation with
    | .insertCoin => "insert coin" | .buy => "BUY" | .askRefund => "REFUND"
    | .motorDelivers => "drink drops" | .motorJams => "motor jams"
    | .retryRefund => "retry the refund"
  s!"{who}: {what}"

end RushGame
