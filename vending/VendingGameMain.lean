import VendingGame
import RushGame
import Lean.Data.Json

open VendingGame Lean

def object (fields : List (String × Json)) : Json := Json.mkObj fields
def str (s : String) : Json := Json.str s
def jsonBool (b : Bool) : Json := toJson b

def parseLevel : String → Except String Level
  | "1" => .ok .simple | "2" => .ok .refunds
  | "3" => .ok .broken | "4" => .ok .repaired
  | _ => .error "Choose a level from 1 to 4."

def parseActions (input : String) : Except String (List Action) := do
  if input.isEmpty then return []
  let names := input.splitOn ","
  if names.length > 32 then throw "At most 32 moves are accepted."
  names.mapM fun name =>
    match Action.all.find? (fun a => a.id == name) with
    | some a => .ok a
    | none => .error s!"Unknown action: {name}. No moves were applied."

def actionJson (level : Level) (s : Node) (a : Action) : Json :=
  match step level s a with
  | none => object [("error", str "Unavailable action")]
  | some t => object [
      ("id", str a.id), ("label", str a.label), ("next", str t.id),
      ("canForce", jsonBool (wins 8 level t)),
      ("rule", str s!"When the state is ‘{s.label}’, {a.label} changes it to ‘{t.label}’.")]

def levelNumber : Level → Nat
  | .simple => 1 | .refunds => 2 | .broken => 3 | .repaired => 4

def businessRules : Json := toJson ([
  object [("rule", str "Payment first: accept a coin before starting delivery."),
    ("representation", str "step level s .buy = some t →\n  s = .credit ∧ t = .dispensing"),
    ("theorem", str "buy_requires_credit")],
  object [("rule", str "Before buying, a refund returns the coin."),
    ("representation", str "replay .repaired .credit\n  [.askRefund, .returnCoin, .coinReturned]\n  = .ok .refunded"),
    ("theorem", str "refund_before_buying")],
  object [("rule", str "If delivery succeeds, give the drink and keep payment."),
    ("representation", str "policyStep .repaired .resolving .motorDelivers\n  = some .served ∧\nNode.served.drinkWithPlayer = true ∧\nNode.served.coinWithPlayer = false"),
    ("theorem", str "delivery_keeps_payment")],
  object [("rule", str "If delivery fails, return the coin."),
    ("representation", str "replay .repaired .resolving\n  [.motorJams, .returnCoin, .coinReturned]\n  = .ok .refunded"),
    ("theorem", str "failed_delivery_refunds")],
  object [("rule", str "While delivery is in progress, keep the refund request pending."),
    ("representation", str "machineChoice .repaired .refundRequested\n  = .waitForMotor"),
    ("theorem", str "hold_refund_while_delivering")],
  object [("rule", str "Business promise: no allowed repaired transaction gives both the drink and the returned coin."),
    ("representation", str "PolicyReachable .repaired s →\n  ¬ (s.coinWithPlayer = true ∧\n     s.drinkWithPlayer = true)"),
    ("theorem", str "repaired_policy_never_gives_both")]
  ] : List Json)

def snapshot (level : Level) (moves : List Action) (enforcePolicy : Bool := false) : Except String Json := do
  let s ← if enforcePolicy then policyReplay level .waiting moves else replay level .waiting moves
  let (_, history) ← moves.foldlM (fun (pair : Node × List Json) a => do
    let (before, events) := pair
    match step level before a with
    | none => throw "Invalid move in history."
    | some after => return (after, events ++ [object [
        ("action", str a.label), ("state", str after.label),
        ("actor", str (if owner before = .machine then "Machine" else "You / dispenser"))]]))
    (Node.waiting, [])
  return object [
    ("level", toJson (levelNumber level)), ("title", str level.title),
    ("node", str s.id), ("state", str s.label),
    ("actor", str (if owner s = .machine then "Machine" else "You / dispenser")),
    ("coinWithPlayer", jsonBool s.coinWithPlayer), ("drinkWithPlayer", jsonBool s.drinkWithPlayer), ("safe", jsonBool (decide (Safe s))), ("settled", jsonBool (decide (Goal s))),
    ("canForce", jsonBool (wins 8 level s)),
    ("initialCanForce", jsonBool (wins 8 level .waiting)),
    ("businessRules", businessRules),
    ("machineChoice", str (machineChoice level s).id),
    ("refundProtected", jsonBool (decide (RefundProtected s))),
    ("counterexample", toJson ((findFailure 8 level .waiting).map (fun trace => trace.map Action.id))),
    ("policyTheorem", str (if level = .repaired then "repaired_policy_never_gives_both"
      else "broken_policy_violates_promise")),
    ("actions", toJson ((enabled level s).map (actionJson level s))),
    ("history", toJson history), ("moves", toJson (moves.map Action.id)),
    ("theorem", str (if level = .broken then "broken_no_strategy" else
      if level = .repaired then "repaired_has_strategy" else
      if level = .simple then "simple_wins + wins_sound" else "refunds_wins + wins_sound")),
    ("scope", str "One coin, one drink, one transaction. You control the listed customer and dispenser outcomes. Every listed reply is covered; endless delays and retries are outside this toy. Rules are rendered from Lean.")]

def command (args : List String) : Except String Json := do
  match args with
  | ["rush-policy", level, actions] => RushGame.command level actions
  | ["play-policy", level, actions] => snapshot (← parseLevel level) (← parseActions actions) true
  | ["play", level, actions] => snapshot (← parseLevel level) (← parseActions actions)
  | ["play", level] => snapshot (← parseLevel level) []
  | [] | ["demo"] =>
      let states ← ([Level.simple, .refunds, .broken, .repaired]).mapM fun l => snapshot l []
      return object [("levels", toJson states)]
  | _ => throw "Usage: vending_game demo | vending_game play <1..4> [comma-separated actions]"

def main (args : List String) : IO UInt32 := do
  match command args with
  | .ok response => IO.println response.compress; return 0
  | .error message => IO.println (object [("error", str message)]).compress; return 1
