import TaxGame.Verify

namespace TaxGame.Audit

def range : List Nat := List.range 2501

def badRaise (w : Nat) : Bool := decide
  (1200 ≤ resources .broken w 0 ∧ resources .broken (w + 1) 0 < 1200)

def badSource (w : Nat) : Bool := decide
  (100 ≤ w ∧ resources .broken w 0 ≠ resources .broken (w - 100) 100)

def badRetry (w : Nat) : Bool := decide
  (1200 ≤ resources .broken w 0 ∧ 1200 < 2 * support .broken w 0)

def findRaise : Option Nat := range.find? badRaise
def findSource : Option Nat := range.find? badSource
def findRetry : Option Nat := range.find? badRetry

theorem found_raise_is_failure (w : Nat) (h : findRaise = some w) :
    1200 ≤ resources .broken w 0 ∧ resources .broken (w + 1) 0 < 1200 := by
  have hp : badRaise w = true := List.find?_some h
  exact of_decide_eq_true hp

theorem found_source_is_failure (w : Nat) (h : findSource = some w) :
    100 ≤ w ∧ resources .broken w 0 ≠ resources .broken (w - 100) 100 := by
  have hp : badSource w = true := List.find?_some h
  exact of_decide_eq_true hp

theorem found_retry_is_failure (w : Nat) (h : findRetry = some w) :
    1200 ≤ resources .broken w 0 ∧ 1200 < 2 * support .broken w 0 := by
  have hp : badRetry w = true := List.find?_some h
  exact of_decide_eq_true hp

#print axioms found_raise_is_failure
#print axioms found_source_is_failure
#print axioms found_retry_is_failure

end TaxGame.Audit
