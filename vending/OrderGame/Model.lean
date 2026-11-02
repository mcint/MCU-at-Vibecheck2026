import Std

namespace OrderGame

inductive Level where
  | simple | cancellation | broken | repaired
  deriving DecidableEq, BEq, Repr

inductive Node where
  | checkout | paid | pending | cancellationRequested | closedPending
  | reconciling | refundDue | refundPending
  | shipped | cancelled | paymentFailed | refunded | chargedAfterClose
  deriving DecidableEq, BEq, Repr

inductive Actor where
  | merchant | environment
  deriving DecidableEq, BEq, Repr

inductive Action where
  | pay | cancel | ship | capture | decline | requestCancellation
  | closeCancellation | awaitCapture | requestRefund | confirmRefund
  deriving DecidableEq, BEq, Repr

def Action.all : List Action :=
  [.pay, .cancel, .ship, .capture, .decline, .requestCancellation,
   .closeCancellation, .awaitCapture, .requestRefund, .confirmRefund]

theorem Action.complete (a : Action) : a ∈ Action.all := by
  cases a <;> simp [Action.all]

def owner : Node → Actor
  | .paid | .cancellationRequested | .refundDue => .merchant
  | _ => .environment

def Safe (s : Node) : Prop := s ≠ .chargedAfterClose

def Goal (s : Node) : Prop :=
  s = .shipped ∨ s = .cancelled ∨ s = .paymentFailed ∨ s = .refunded

instance (s : Node) : Decidable (Safe s) := inferInstanceAs (Decidable (s ≠ .chargedAfterClose))
instance (s : Node) : Decidable (Goal s) := by unfold Goal; infer_instance

/-- The authoritative reference interpreter. A missing case is a rejected action.
    There are no outgoing transitions from settled goals or the failure state. -/
def step (level : Level) (s : Node) (a : Action) : Option Node :=
  match s, a with
  | .checkout, .pay =>
      some (if level = .simple ∨ level = .cancellation then .paid else .pending)
  | .checkout, .cancel => if level = .simple then none else some .cancelled
  | .paid, .ship => some .shipped
  | .pending, .capture => some .paid
  | .pending, .decline => some .paymentFailed
  | .pending, .requestCancellation => some .cancellationRequested
  | .cancellationRequested, .closeCancellation => some .closedPending
  | .cancellationRequested, .awaitCapture =>
      if level = .repaired then some .reconciling else none
  | .closedPending, .capture => some .chargedAfterClose
  | .closedPending, .decline => some .cancelled
  | .reconciling, .capture => some .refundDue
  | .reconciling, .decline => some .cancelled
  | .refundDue, .requestRefund => some .refundPending
  | .refundPending, .confirmRefund => some .refunded
  | _, _ => none

def enabled (level : Level) (s : Node) : List Action :=
  Action.all.filter (fun a => (step level s a).isSome)

theorem enabled_iff (level : Level) (s : Node) (a : Action) :
    a ∈ enabled level s ↔ (step level s a).isSome = true := by
  simp [enabled, Action.complete]

theorem goals_have_no_moves (level : Level) (s : Node) (h : Goal s) :
    enabled level s = [] := by
  rcases h with h | h | h | h <;> subst s <;>
    simp [enabled, Action.all, step]

def replay (level : Level) : Node → List Action → Except String Node
  | s, [] => .ok s
  | s, a :: rest =>
      match step level s a with
      | none => .error "That action is not enabled. The entire move list was rejected."
      | some t => replay level t rest

def Node.label : Node → String
  | .checkout => "An order is ready"
  | .paid => "Payment captured; ready to ship"
  | .pending => "Payment capture is in flight"
  | .cancellationRequested => "Customer wants to cancel; capture is still in flight"
  | .closedPending => "Cancellation closed locally; provider has not replied"
  | .reconciling => "Cancellation pending; awaiting provider outcome"
  | .refundDue => "Late capture confirmed; a refund is required"
  | .refundPending => "Refund requested; awaiting confirmation"
  | .shipped => "Order shipped"
  | .cancelled => "Order cancelled without a captured payment"
  | .paymentFailed => "Payment failed; order closed"
  | .refunded => "Refund confirmed; cancellation settled"
  | .chargedAfterClose => "Failure: customer charged after cancellation was closed"

def Node.id (s : Node) : String := (repr s).pretty |>.splitOn "." |>.getLast!

def Action.id : Action → String
  | .pay => "pay" | .cancel => "cancel" | .ship => "ship"
  | .capture => "capture" | .decline => "decline"
  | .requestCancellation => "requestCancellation"
  | .closeCancellation => "closeCancellation" | .awaitCapture => "awaitCapture"
  | .requestRefund => "requestRefund" | .confirmRefund => "confirmRefund"

def Action.label : Action → String
  | .pay => "Pay for the order" | .cancel => "Cancel before payment"
  | .ship => "Ship the order" | .capture => "Provider confirms capture"
  | .decline => "Provider declines capture"
  | .requestCancellation => "Customer requests cancellation"
  | .closeCancellation => "Close cancellation immediately"
  | .awaitCapture => "Keep cancellation pending"
  | .requestRefund => "Request a refund" | .confirmRefund => "Provider confirms refund"

def Level.title : Level → String
  | .simple => "1. Pay and ship"
  | .cancellation => "2. Add cancellation"
  | .broken => "3. Add delayed capture — broken"
  | .repaired => "4. Reconcile and refund — repaired"

end OrderGame
