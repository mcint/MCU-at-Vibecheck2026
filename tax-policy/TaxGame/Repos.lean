import TaxGame.Model
import LeanContracts.Basic
import LeanContracts.Semantics

namespace TaxGame.Repos
open LeanContracts

/-- Actually evaluated with the unmodified, vendored LeanContracts engine. -/
def oldSupportContract : Contract :=
  both
    (cond (.ltFloat (.var "wages") (.constFloat 1000.0)) (pay 600.0) zero)
    (cond (.ltFloat .income (.constFloat 1200.0)) (pay 400.0) zero)

def context (wages side : Nat) : Context :=
  { income := Float.ofNat (wages + side), vars := [("wages", Float.ofNat wages)] }

def crossCheck (wages side : Nat) : Bool :=
  evaluate (context wages side) oldSupportContract == Float.ofNat (support .broken wages side)

/-- Port of Catala's section 132(c)(1)(B) example, in whole-dollar units.
    The UI requires prices divisible by 5; this is not a full statutory model. -/
def serviceDiscountCap (customerPrice employeePrice : Nat) : Nat :=
  min (customerPrice - employeePrice) (customerPrice / 5)

theorem service_cap_bounded (customerPrice employeePrice : Nat) :
    serviceDiscountCap customerPrice employeePrice ≤ customerPrice / 5 ∧
    serviceDiscountCap customerPrice employeePrice ≤ customerPrice - employeePrice := by
  exact ⟨Nat.min_le_right _ _, Nat.min_le_left _ _⟩

theorem demo_discount : serviceDiscountCap 100 50 = 20 := by decide

end TaxGame.Repos
