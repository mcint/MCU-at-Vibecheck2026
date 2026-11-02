import TaxGame.Verify

namespace TaxGame.Interdomain

/-!
2026 federal Marketplace Premium Tax Credit example, restricted to the 300–400% FPL band.
The premium is KFF's 2026 Texas state average benchmark premium for a 40-year-old ($661/month),
used as both the benchmark and selected plan premium for this representative example.
This is not a personalized eligibility or premium determination.
-/

def povertyGuideline : Nat := 15650
def lowerModeledIncome : Nat := 3 * povertyGuideline
def cutoffIncome : Nat := 4 * povertyGuideline
def benchmarkPremium : Nat := 661
def applicableRateBasisPoints : Nat := 996

/-- Form 8962 line 8a/8b style nearest whole-dollar rounding for positive amounts. -/
def roundDiv (amount divisor : Nat) : Nat := (amount + divisor / 2) / divisor

/-- The 2026 applicable percentage in the 300–400% FPL band is 9.96%. -/
def annualContribution (income : Nat) : Nat :=
  roundDiv (income * applicableRateBasisPoints) 10000

def monthlyContribution (income : Nat) : Nat :=
  roundDiv (annualContribution income) 12

/-- Federal PTC in the modeled 300–400% FPL band. Eligibility above 400% is zero. -/
def currentCredit (income : Nat) : Nat :=
  if income < lowerModeledIncome then 0
  else if income ≤ cutoffIncome then benchmarkPremium - monthlyContribution income
  else 0

def currentPremiumPaid (income : Nat) : Nat := benchmarkPremium - currentCredit income

/--
Hypothetical policy only: preserve the cutoff credit, then taper it linearly to zero over
the next half-FPL of income. This is an illustrative repair, not enacted law.
-/
def proposedCredit (income : Nat) : Nat :=
  if income < lowerModeledIncome then 0
  else if income ≤ cutoffIncome then currentCredit income
  else
    let initial := currentCredit cutoffIncome
    let width := povertyGuideline / 2
    let reduction := min initial (((income - cutoffIncome) * initial) / width)
    initial - reduction

def proposedPremiumPaid (income : Nat) : Nat := benchmarkPremium - proposedCredit income

theorem fpl_cutoff_is_62600 : cutoffIncome = 62600 := by decide
theorem contribution_at_cutoff_is_520 : monthlyContribution cutoffIncome = 520 := by decide
theorem credit_at_cutoff_is_141 : currentCredit cutoffIncome = 141 := by decide
theorem credit_one_dollar_over_is_zero : currentCredit (cutoffIncome + 1) = 0 := by decide
theorem premium_at_cutoff_is_520 : currentPremiumPaid cutoffIncome = 520 := by decide
theorem premium_one_dollar_over_is_661 : currentPremiumPaid (cutoffIncome + 1) = 661 := by decide

theorem current_credit_zero_above_cutoff (income : Nat) (h : cutoffIncome < income) :
    currentCredit income = 0 := by
  by_cases hlo : income < lowerModeledIncome
  · simp [currentCredit, hlo]
  · have hhi : ¬ income ≤ cutoffIncome := by omega
    simp [currentCredit, hlo, hhi]

theorem current_premium_full_above_cutoff (income : Nat) (h : cutoffIncome < income) :
    currentPremiumPaid income = benchmarkPremium := by
  simp [currentPremiumPaid, current_credit_zero_above_cutoff income h]

/-- At the eligibility boundary, a one-dollar annual MAGI increase removes the credit. -/
theorem real_cutoff_cliff :
    currentCredit cutoffIncome = 141 ∧
    currentCredit (cutoffIncome + 1) = 0 ∧
    currentPremiumPaid (cutoffIncome + 1) - currentPremiumPaid cutoffIncome = 141 := by
  decide

theorem current_credit_bounded (income : Nat) : currentCredit income ≤ benchmarkPremium := by
  by_cases hlow : income < lowerModeledIncome
  · simp [currentCredit, hlow, benchmarkPremium]
  · by_cases hhigh : income ≤ cutoffIncome
    · simp [currentCredit, hlow, hhigh, benchmarkPremium]
    · simp [currentCredit, hlow, hhigh, benchmarkPremium]

theorem proposed_credit_bounded (income : Nat) : proposedCredit income ≤ benchmarkPremium := by
  by_cases hlo : income < lowerModeledIncome
  · simp [proposedCredit, hlo, benchmarkPremium]
  · by_cases hhi : income ≤ cutoffIncome
    · simp [proposedCredit, hlo, hhi]
      exact current_credit_bounded income
    · have hExact := credit_at_cutoff_is_141
      have hsub : 141 - min 141 (((income - cutoffIncome) * 141) / (povertyGuideline / 2)) ≤ 141 :=
        Nat.sub_le _ _
      have hcap : 141 ≤ benchmarkPremium := by decide
      simpa [proposedCredit, hlo, hhi, hExact] using Nat.le_trans hsub hcap

/-- The proposed phase-out removes the eligibility cliff at the exact 400% boundary. -/
theorem proposed_boundary_continuous :
    proposedCredit cutoffIncome = proposedCredit (cutoffIncome + 1) := by
  decide

def cliffWitness (income : Nat) : Bool :=
  decide (currentCredit income > 0 ∧ currentCredit (income + 1) = 0)

def findCliff : Option Nat := (List.range 1001).find? fun offset =>
  cliffWitness (cutoffIncome - 500 + offset)

theorem found_cliff_is_failure (offset : Nat) (h : findCliff = some offset) :
    cliffWitness (cutoffIncome - 500 + offset) = true := by
  have hf := List.find?_some h
  simpa [findCliff] using hf

/-! ### Headline pair: current law has a cliff; the repair has none, for every income. -/

/-- Closed arithmetic form of the hypothetical credit, with every constant unfolded. -/
theorem proposedCredit_arith (income : Nat) : proposedCredit income =
    if income < 46950 then 0
    else if income ≤ 62600 then 661 - ((income * 996 + 5000) / 10000 + 6) / 12
    else 141 - min 141 (((income - 62600) * 141) / 7825) := by
  simp only [proposedCredit, credit_at_cutoff_is_141]
  simp only [currentCredit, monthlyContribution, annualContribution, roundDiv,
    lowerModeledIncome, cutoffIncome, povertyGuideline, benchmarkPremium,
    applicableRateBasisPoints, Nat.reduceMul, Nat.reduceDiv]
  by_cases ha : income < 46950
  · simp [ha]
  · by_cases hb : income ≤ 62600 <;> simp [ha, hb]

/-- Under the hypothetical taper, the credit falls by at most $1 per extra dollar of income. -/
theorem proposed_credit_lipschitz (income : Nat) :
    proposedCredit income ≤ proposedCredit (income + 1) + 1 := by
  rw [proposedCredit_arith, proposedCredit_arith]
  by_cases ha : income < 46950
  · simp [ha]
  · have hd : ¬ income + 1 < 46950 := by omega
    by_cases hc : income ≤ 62600
    · by_cases he : income + 1 ≤ 62600
      · simp only [ha, hc, hd, he, ite_true, ite_false]
        have h1 : (income + 1) * 996 = income * 996 + 996 := by rw [Nat.add_mul, Nat.one_mul]
        rw [h1]; omega
      · have hcut : income = 62600 := by omega
        subst hcut; decide
    · have he : ¬ income + 1 ≤ 62600 := by omega
      simp only [ha, hc, hd, he, ite_false]
      have h2 : (income + 1 - 62600) * 141 = (income - 62600) * 141 + 141 := by
        rw [Nat.sub_add_comm (by omega), Nat.add_mul, Nat.one_mul]
      rw [h2]; omega

/-- Under the hypothetical repair, a $1 annual raise never raises the monthly premium by more
than $1, for every income (not just at the boundary). -/
theorem proposed_no_cliff (income : Nat) :
    proposedPremiumPaid (income + 1) ≤ proposedPremiumPaid income + 1 := by
  have hb := proposed_credit_bounded income
  have hl := proposed_credit_lipschitz income
  unfold proposedPremiumPaid
  omega

/-- Under current law there is an income where a $1 raise adds $141/month to the premium. -/
theorem current_has_cliff :
    ∃ income, currentPremiumPaid (income + 1) = currentPremiumPaid income + 141 :=
  ⟨cutoffIncome, by decide⟩

#print axioms real_cutoff_cliff
#print axioms current_credit_zero_above_cutoff
#print axioms proposed_credit_bounded
#print axioms proposed_boundary_continuous
#print axioms found_cliff_is_failure
#print axioms proposed_no_cliff
#print axioms current_has_cliff

end TaxGame.Interdomain
