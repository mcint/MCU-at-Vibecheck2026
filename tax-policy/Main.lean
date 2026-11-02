import TaxGame
import Lean.Data.Json

open TaxGame Lean
private def obj := Json.mkObj
private def str := Json.str
private def jb (b : Bool) : Json := toJson b

def ruleRows : Json := toJson ([
  obj [("rule", str "Old work support stops at 1000 wages and ignores side work."),
    ("lean", str "if wages < 1000 then 600 else 0"), ("theorem", str "old_source_loophole")],
  obj [("rule", str "Old housing support stops at 1200 total earnings."),
    ("lean", str "if wages + side < 1200 then 400 else 0"), ("theorem", str "old_one_dollar_cliff")],
  obj [("rule", str "Repaired support tapers against all net work earnings."),
    ("lean", str "support .repaired wages side =\n  1200 - net (wages + side) / 2"), ("theorem", str "repaired_support_bounded")],
  obj [("rule", str "Resources after tax and eligible support reach at least 1200."),
    ("lean", str "∀ wages side, 1200 ≤ resources .repaired wages side"), ("theorem", str "repaired_floor")],
  obj [("rule", str "Earning more cannot reduce resources."),
    ("lean", str "w₁ + s₁ ≤ w₂ + s₂ →\n  resources .repaired w₁ s₁ ≤ resources .repaired w₂ s₂"), ("theorem", str "repaired_monotone")],
  obj [("rule", str "The same total work earnings receive the same treatment."),
    ("lean", str "w₁ + s₁ = w₂ + s₂ →\n  resources .repaired w₁ s₁ = resources .repaired w₂ s₂"), ("theorem", str "repaired_source_neutral")],
  obj [("rule", str "A filed assessment pays once; retries acknowledge it."),
    ("lean", str "s.claimed = true → step .repaired s .retry = some s"), ("theorem", str "repaired_retry_idempotent")],
  obj [("rule", str "Every accepted repaired history satisfies all five promises."),
    ("lean", str "replay .repaired (initial wages side) moves = .ok s →\n  Safe .repaired s"), ("theorem", str "accepted_repaired_history_safe")]
  ] : List Json)

private def causeRow (title why : String) (before after : Nat) (code : String) (unit : String := "money") : Json :=
  obj [("title", str title), ("why", str why), ("before", toJson before), ("after", toJson after),
    ("lean", str code), ("unit", str unit)]

private def causes (p : Policy) (b s : State) (last : Option Action) : Json :=
  let bt := b.wages + b.side
  let st := s.wages + s.side
  let policyName := if p = .broken then "broken" else "repaired"
  let resourceCode := s!"resources .{policyName} {b.wages} {b.side} = {resources p b.wages b.side}\nresources .{policyName} {s.wages} {s.side} = {resources p s.wages s.side}"
  if last = some .file ∨ last = some .retry then
    toJson ([
      causeRow "Eligible support" "The assessed amount is fixed for this period." (support p b.wages b.side) (support p s.wages s.side)
        s!"support .{policyName} {s.wages} {s.side} = {support p s.wages s.side}",
      causeRow "Support actually paid" (if p = .broken then "The old rule adds another payout on each filing." else "The repaired rule pays the first assessment once.") b.paid s.paid
        (if p = .repaired ∧ b.claimed then "-- already filed\nfiled .repaired s = s" else s!"-- add the eligible support\n{b.paid} + {support p b.wages b.side} = {s.paid}"),
      causeRow "Number of awards" (if p = .broken then "A retry is treated as another award." else "A retry is an acknowledgement, not another award.") b.payments s.payments
        (if p = .repaired ∧ b.claimed then s!"-- same assessment, no new award\n{s.payments} = {b.payments}" else s!"-- one more award\n{b.payments} + 1 = {s.payments}") "count",
      causeRow "Household allocation used" "This household has a 1200 allocation for the period." b.paid s.paid
        s!"decide ({s.paid} ≤ 1200) = {decide (s.paid ≤ 1200)}"
      ] : List Json)
  else
    toJson ([
      causeRow "Your work earnings" (if last = some .shift100 then "Only the earnings label changes; total work earnings stay the same." else "The employer raises your wages.") bt st
        s!"{b.wages} + {b.side} = {bt}\n{s.wages} + {s.side} = {st}",
      causeRow (if last = some .shift100 then (if p = .broken then "Work-support rule" else "Combined support") else "Tax")
        (if last = some .shift100 then (if p = .broken then "The old eligibility test looks at wages alone, even when total work earnings are unchanged." else "The repaired rule uses total work earnings, regardless of their label.") else "Tax is 10% of total work earnings, rounded down.")
        (if last = some .shift100 then (if p = .broken then oldWorkSupport b.wages else support p b.wages b.side) else tax bt)
        (if last = some .shift100 then (if p = .broken then oldWorkSupport s.wages else support p s.wages s.side) else tax st)
        (if last = some .shift100 then (if p = .broken then s!"oldWorkSupport {b.wages} = {oldWorkSupport b.wages}\noldWorkSupport {s.wages} = {oldWorkSupport s.wages}" else s!"support .repaired {b.wages} {b.side} = {support p b.wages b.side}\nsupport .repaired {s.wages} {s.side} = {support p s.wages s.side}")
          else s!"tax {bt} = {tax bt}\ntax {st} = {tax st}"),
      causeRow (if p = .broken then "Housing support" else "Repaired combined support")
        (if p = .broken then "Pay 400 only while total work earnings are below 1200. At 1200, this support ends." else "Replace the cutoff with a gradual taper based on total net earnings.")
        (if p = .broken then oldHousingSupport bt else support p b.wages b.side)
        (if p = .broken then oldHousingSupport st else support p s.wages s.side)
        (if p = .broken then s!"oldHousingSupport {bt} = {oldHousingSupport bt}\noldHousingSupport {st} = {oldHousingSupport st}"
          else s!"support .repaired {b.wages} {b.side} = {support p b.wages b.side}\nsupport .repaired {s.wages} {s.side} = {support p s.wages s.side}"),
      causeRow "Money to live on" "Work earnings minus tax, plus eligible support." (resources p b.wages b.side) (resources p s.wages s.side) resourceCode
      ] : List Json)

def snapshot (p : Policy) (wages side : Nat) (moves : List Action) : Except String Json := do
  let s ← replay p (initial wages side) moves
  let before ← replay p (initial wages side) moves.dropLast
  let total := s.wages + s.side
  let floorOk := decide (1200 ≤ resources p s.wages s.side)
  let budgetOk := decide (s.paid ≤ 1200)
  let onceOk := decide (s.payments ≤ 1)
  let violations := (if floorOk then [] else ["Below the 1200 resource floor"]) ++
    (if s.noCliff then [] else ["Earning more made the household poorer"]) ++
    (if s.fairSources then [] else ["Same total income, different support"]) ++
    (if budgetOk then [] else ["Household allocation exceeded"]) ++
    (if onceOk then [] else ["Same assessment paid more than once"])
  let actions := (enabled p s).map fun a =>
    obj [("id", str a.id), ("label", str a.label)]
  let maxWages := max 3000 (s.wages + 200)
  let sampleWages := ((List.range 101).map (fun i => maxWages * i / 100) ++ [999, 1000, 1199, 1200]).mergeSort (· ≤ ·)
  let curve := sampleWages.map fun w =>
    obj [("earnings", toJson (w + s.side)), ("old", toJson (resources .broken w s.side)),
      ("fixed", toJson (resources .repaired w s.side))]
  return obj [
    ("policy", str (if p = .broken then "old" else "fixed")),
    ("startWages", toJson wages), ("startSide", toJson side),
    ("wages", toJson s.wages), ("side", toJson s.side), ("earnings", toJson total),
    ("tax", toJson (tax total)), ("netEarned", toJson (net total)),
    ("support", toJson (support p s.wages s.side)),
    ("workSupport", toJson (if p = .broken ∧ s.wages < 1000 then (600 : Nat) else 0)),
    ("housingSupport", toJson (if p = .broken ∧ total < 1200 then (400 : Nat) else 0)),
    ("resources", toJson (resources p s.wages s.side)),
    ("paid", toJson s.paid), ("payments", toJson s.payments), ("claimed", jb s.claimed),
    ("floor", toJson (1200 : Nat)), ("allocation", toJson (1200 : Nat)),
    ("promises", obj [("floor", jb floorOk), ("noCliff", jb s.noCliff),
      ("fairSources", jb s.fairSources), ("budget", jb budgetOk), ("paidOnce", jb onceOk)]),
    ("safe", jb (decide (Safe p s))), ("violations", toJson violations),
    ("formalState", str s.formal), ("actions", toJson actions), ("moves", toJson (moves.map Action.id)),
    ("rules", ruleRows), ("curve", toJson curve),
    ("causes", causes p before s moves.getLast?),
    ("housingRule", str "def oldHousingSupport (earnings : Nat) : Nat :=\n  if earnings < 1200 then 400 else 0"),
    ("beforeResources", toJson (resources p before.wages before.side)),
    ("beforePaid", toJson before.paid),
    ("theorem", str (if p = .repaired then "TaxGame.accepted_repaired_history_safe" else "TaxGame.old_one_dollar_cliff + old_source_loophole + old_duplicate_payout")),
    ("github", obj [("contractAmount", str (toString (LeanContracts.evaluate (TaxGame.Repos.context s.wages s.side) TaxGame.Repos.oldSupportContract))), ("agrees", jb (TaxGame.Repos.crossCheck s.wages s.side)), ("trace", toJson (LeanContracts.evaluateTrace (TaxGame.Repos.context s.wages s.side) TaxGame.Repos.oldSupportContract).1), ("catalaCap", toJson (TaxGame.Repos.serviceDiscountCap 100 50))]),
    ("scope", str "Fictional monthly rules, one household, whole monetary units. Resources include eligible support; paid records actual disbursement separately. Income is fixed after filing for this period. The 1200 allocation is for this household, not a government-wide budget. This does not prove real poverty eradication or legal compliance.")]

def audit (kind : String) : Except String Json := do
  let (found, title, actions, explanation, fix, proof, statement, soundness) ← match kind with
    | "cliff" => .ok (Audit.findRaise, "Find a raise that makes a household poorer", [Action.raise1],
        "Search for a household above the resource floor where a one-unit raise drops it below that floor.",
        "Replace abrupt support cutoffs with a gradual taper against total net work earnings.",
        "TaxGame.repaired_monotone + TaxGame.repaired_floor",
        "more total earnings → no fewer resources; resources ≥ 1200",
        "TaxGame.Audit.found_raise_is_failure")
    | "source" => .ok (Audit.findSource, "Find unequal help for equal earnings", [Action.shift100],
        "Search for equal total work earnings that receive different support when their wage/side-work labels change.",
        "Use total work earnings consistently, rather than checking wages alone.",
        "TaxGame.repaired_source_neutral",
        "equal total work earnings → equal resources",
        "TaxGame.Audit.found_source_is_failure")
    | "retry" => .ok (Audit.findRetry, "Find an assessment that pays twice", [Action.file, .retry],
        "Search for an initially safe household where repeating a support payment exceeds its allocation.",
        "Remember the first filed assessment and acknowledge retries without paying again.",
        "TaxGame.repaired_retry_idempotent + accepted_repaired_history_safe",
        "already filed → retry leaves the state unchanged; all accepted repaired histories are safe",
        "TaxGame.Audit.found_retry_is_failure")
    | _ => .error "Choose cliff, source, or retry."
  let wages ← match found with
    | some w => .ok w
    | none => .error "No failing household was found in the stated search range."
  let old ← snapshot .broken wages 0 actions
  let fixed ← snapshot .repaired wages 0 actions
  return obj [("source", str "Lean model search"), ("kind", str kind),
    ("title", str title), ("tactic", str explanation), ("wages", toJson wages), ("side", toJson (0 : Nat)),
    ("moves", toJson (actions.map Action.id)), ("scope", str "Starting wages 0..2500, side income 0; the indicated action sequence. Search is bounded; repaired arithmetic and replay proofs are not."),
    ("fix", str fix), ("proof", str proof), ("statement", str statement),
    ("searchSoundness", str soundness), ("oldResult", old), ("fixedResult", fixed)]

def discountCase (price employeePrice : Nat) : Except String Json := do
  if price = 0 ∨ price > 10000 ∨ price % 5 ≠ 0 ∨ employeePrice > price then
    throw "Use a customer price from 5 to 10000 divisible by 5, and employee price between 0 and customer price."
  let actual := price - employeePrice
  let cap := price / 5
  let corrected := Repos.serviceDiscountCap price employeePrice
  return obj [("price", toJson price), ("employeePrice", toJson employeePrice),
    ("actualDiscount", toJson actual), ("limit", toJson cap),
    ("uncheckedClaim", toJson actual), ("qualifiedPortion", toJson corrected),
    ("aboveCap", toJson (actual - corrected)),
    ("claimWithinCap", jb (actual ≤ cap)),
    ("fixedWithinCap", jb (corrected ≤ cap)),
    ("fixedWithinDiscount", jb (corrected ≤ actual)),
    ("lean", str s!"serviceDiscountCap {price} {employeePrice}\n= min ({price} - {employeePrice}) ({price} / 5)\n= {corrected}"),
    ("proof", str "TaxGame.Repos.service_cap_bounded"),
    ("statement", str "For all natural prices, the capped amount is at most customerPrice/5 and at most the actual discount."),
    ("source", str "CatalaLang/catala-examples · 9e251b932288 · section_132.catala_en"),
    ("scope", str "Restricted services-discount cap example ported from the pinned Catala source. Whole-dollar customer prices divisible by 5; other qualification/eligibility requirements and complete tax liability are outside this calculation. The amount above the cap is not a tax bill.")]

private def interdomainSnapshot (income : Nat) (proposed : Bool) : Json :=
  let credit := if proposed then Interdomain.proposedCredit income else Interdomain.currentCredit income
  let premium := if proposed then Interdomain.proposedPremiumPaid income else Interdomain.currentPremiumPaid income
  obj [("income", toJson income), ("annualContribution", toJson (Interdomain.annualContribution income)),
    ("monthlyContribution", toJson (Interdomain.monthlyContribution income)),
    ("eligible", jb (income ≤ Interdomain.cutoffIncome)), ("credit", toJson credit),
    ("premium", toJson premium), ("annualIncomeAfterPremium", toJson (income - 12 * premium))]

def interdomainCase : Except String Json := do
  let offset ← match Interdomain.findCliff with
    | some i => .ok i
    | none => .error "No threshold witness found in the stated Lean search interval."
  let income := Interdomain.cutoffIncome - 500 + offset
  let boundary := Interdomain.cutoffIncome
  return obj [("source", str "Native Lean evaluation of the modeled 2026 PTC rules"),
    ("fpl", toJson Interdomain.povertyGuideline), ("cutoff", toJson boundary),
    ("benchmarkPremium", toJson Interdomain.benchmarkPremium),
    ("taperWidth", toJson (Interdomain.povertyGuideline / 2)),
    ("annualCreditLoss", toJson (12 * Interdomain.currentCredit boundary)),
    ("rateBasisPoints", toJson Interdomain.applicableRateBasisPoints),
    ("witnessIncome", toJson income), ("searchStart", toJson (boundary - 500)),
    ("searchEnd", toJson (boundary + 500)),
    ("curve", toJson ((List.range 301).map fun i =>
      let earnings := boundary - 150 + i
      obj [("income", toJson earnings),
        ("current", toJson (Interdomain.currentPremiumPaid earnings)),
        ("proposed", toJson (Interdomain.proposedPremiumPaid earnings)),
        ("currentPTC", toJson (Interdomain.currentCredit earnings)),
        ("proposedPTC", toJson (Interdomain.proposedCredit earnings))])),
    ("before", interdomainSnapshot boundary false),
    ("after", interdomainSnapshot (boundary + 1) false),
    ("proposedBefore", interdomainSnapshot boundary true),
    ("proposedAfter", interdomainSnapshot (boundary + 1) true),
    ("proof", str "TaxGame.Interdomain.real_cutoff_cliff"),
    ("repairProof", str "TaxGame.Interdomain.proposed_boundary_continuous"),
    ("searchSoundness", str "TaxGame.Interdomain.found_cliff_is_failure"),
    ("scope", str "2026 federal Marketplace PTC calculation restricted to 300–400% FPL and the adjacent ineligible income. One-person tax family, single filer not claimed as a dependent, 2025 contiguous-state FPL $15,650, 40-year-old Texas benchmark average $661/month. Assumes full-year Marketplace enrollment in the benchmark plan and no affordable employer or government coverage. Excludes ordinary income/payroll taxes, state aid, individual plan variation and cost sharing. Proposed taper is hypothetical, not current law.")]

/-- One income point under both rules, plus the $1-raise neighbour: feeds the demo's MAGI slider. -/
def ptcCase (income : Nat) : Except String Json := do
  if income > 200000 then throw "Annual MAGI must be at most 200000 for this model."
  let cur := Interdomain.currentPremiumPaid income
  let curNext := Interdomain.currentPremiumPaid (income + 1)
  let prop := Interdomain.proposedPremiumPaid income
  let propNext := Interdomain.proposedPremiumPaid (income + 1)
  return obj [("source", str "Native Lean evaluation of the modeled 2026 PTC rules"),
    ("income", toJson income),
    ("current", interdomainSnapshot income false),
    ("currentAfterRaise", interdomainSnapshot (income + 1) false),
    ("proposed", interdomainSnapshot income true),
    ("proposedAfterRaise", interdomainSnapshot (income + 1) true),
    ("currentRaiseCost", toJson (curNext - cur)),
    ("proposedRaiseCost", toJson (propNext - prop)),
    ("proposedNoCliffHolds", jb (propNext ≤ prop + 1)),
    ("aboveCutoff", jb (Interdomain.cutoffIncome < income)),
    ("proof", str "TaxGame.Interdomain.proposed_no_cliff"),
    ("cliffProof", str "TaxGame.Interdomain.current_has_cliff")]

def command (args : List String) : Except String Json := do
  match args with
  | ["interdomain"] => interdomainCase
  | ["ptc", i] =>
      match i.toNat? with
      | some income => ptcCase income
      | none => .error "Annual MAGI must be a nonnegative whole-dollar integer."
  | ["discount", p, e] =>
      match p.toNat?, e.toNat? with
      | some price, some employee => discountCase price employee
      | _, _ => .error "Prices must be nonnegative whole dollars."
  | ["audit", kind] => audit kind
  | ["play", policy, w, s, input] =>
      let p ← match policy with
        | "old" => .ok Policy.broken | "fixed" => .ok Policy.repaired
        | _ => .error "Choose old or fixed policy."
      let wages ← match w.toNat? with
        | some n => .ok n | none => .error "Starting wages must be a nonnegative integer."
      let side ← match s.toNat? with
        | some n => .ok n | none => .error "Starting side income must be a nonnegative integer."
      if wages > 5000 ∨ side > 5000 then throw "Starting incomes must be at most 5000 each."
      let names := if input.isEmpty then [] else input.splitOn ","
      if names.length > 24 then throw "At most 24 actions per request."
      let moves ← names.mapM fun name =>
        match Action.all.find? (fun a => a.id == name) with
        | some a => .ok a | none => .error s!"Unknown action: {name}"
      snapshot p wages side moves
  | _ => throw "Usage: tax_game play <old|fixed> <wages> <side> <comma-separated moves>"

def main (args : List String) : IO UInt32 := do
  match command args with
  | .ok result => IO.println result.compress; return 0
  | .error message =>
      let kind := if message.startsWith "That action is unavailable:" then "transition" else "input"
      IO.println (obj [("error", str message), ("errorKind", str kind)]).compress
      return 1
