import Std

namespace TaxGame

inductive Policy where
  | broken | repaired
  deriving DecidableEq, BEq, Repr

def tax (earnings : Nat) : Nat := earnings / 10
def net (earnings : Nat) : Nat := earnings - tax earnings

def oldWorkSupport (wages : Nat) : Nat := if wages < 1000 then 600 else 0
def oldHousingSupport (earnings : Nat) : Nat := if earnings < 1200 then 400 else 0

def support (policy : Policy) (wages side : Nat) : Nat :=
  match policy with
  | .broken => oldWorkSupport wages + oldHousingSupport (wages + side)
  | .repaired => 1200 - net (wages + side) / 2

def resources (policy : Policy) (wages side : Nat) : Nat :=
  net (wages + side) + support policy wages side

structure State where
  wages : Nat
  side : Nat
  paid : Nat := 0
  payments : Nat := 0
  claimed : Bool := false
  noCliff : Bool := true
  fairSources : Bool := true
  deriving DecidableEq, BEq, Repr

def initial (wages side : Nat) : State := { wages, side }

inductive Action where
  | raise1 | raise100 | shift100 | file | retry
  deriving DecidableEq, BEq, Repr

def Action.all : List Action := [.raise1, .raise100, .shift100, .file, .retry]
theorem Action.complete (a : Action) : a ∈ Action.all := by cases a <;> simp [Action.all]

def raised (policy : Policy) (s : State) (amount : Nat) : State :=
  { s with wages := s.wages + amount, noCliff := s.noCliff && decide (resources policy s.wages s.side ≤
      resources policy (s.wages + amount) s.side) }

def shifted (policy : Policy) (s : State) : State :=
  { s with wages := s.wages - 100, side := s.side + 100, fairSources := s.fairSources && decide (resources policy s.wages s.side =
      resources policy (s.wages - 100) (s.side + 100)) }

def filed (policy : Policy) (s : State) : State :=
  if policy = .repaired ∧ s.claimed = true then s else
    { s with paid := s.paid + support policy s.wages s.side, payments := s.payments + 1, claimed := true }

def step (policy : Policy) (s : State) : Action → Option State
  | .raise1 => if s.claimed then none else some (raised policy s 1)
  | .raise100 => if s.claimed then none else some (raised policy s 100)
  | .shift100 => if s.claimed ∨ s.wages < 100 then none else some (shifted policy s)
  | .file => some (filed policy s)
  | .retry => if s.claimed then some (filed policy s) else none

def enabled (policy : Policy) (s : State) : List Action :=
  Action.all.filter (fun a => (step policy s a).isSome)

theorem enabled_iff (policy : Policy) (s : State) (a : Action) :
    a ∈ enabled policy s ↔ (step policy s a).isSome = true := by
  simp [enabled, Action.complete]

def replay (policy : Policy) : State → List Action → Except String State
  | s, [] => .ok s
  | s, a :: rest =>
      match step policy s a with
      | none => .error "That action is unavailable: income is fixed after filing; retries require an existing filing."
      | some next => replay policy next rest

inductive Reachable (policy : Policy) (wages side : Nat) : State → Prop where
  | start : Reachable policy wages side (initial wages side)
  | next {s a t} : Reachable policy wages side s → step policy s a = some t →
      Reachable policy wages side t

def Safe (policy : Policy) (s : State) : Prop :=
  1200 ≤ resources policy s.wages s.side ∧ s.noCliff = true ∧
  s.fairSources = true ∧ s.paid ≤ 1200 ∧ s.payments ≤ 1

instance (p : Policy) (s : State) : Decidable (Safe p s) := by unfold Safe; infer_instance

def Action.id (a : Action) : String := (repr a).pretty |>.splitOn "." |>.getLast!
def Action.label : Action → String
  | .raise1 => "Accept a $1 raise" | .raise100 => "Earn $100 more"
  | .shift100 => "Move $100 to side-work income"
  | .file => "File for support" | .retry => "Retry the same filing"

def State.formal (s : State) : String :=
  s!"⟨{s.wages}, {s.side}, {s.paid}, {s.payments}, {s.claimed}, {s.noCliff}, {s.fairSources}⟩"

end TaxGame
