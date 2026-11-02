import OrderGame
import Lean.Data.Json

open OrderGame Lean

def object (fields : List (String × Json)) : Json := Json.mkObj fields
def str (s : String) : Json := Json.str s
def jsonBool (b : Bool) : Json := toJson b

def parseLevel : String → Except String Level
  | "1" => .ok .simple | "2" => .ok .cancellation
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
  | .simple => 1 | .cancellation => 2 | .broken => 3 | .repaired => 4

def snapshot (level : Level) (moves : List Action) : Except String Json := do
  let s ← replay level .checkout moves
  let (_, history) ← moves.foldlM (fun (pair : Node × List Json) a => do
    let (before, events) := pair
    match step level before a with
    | none => throw "Invalid move in history."
    | some after => return (after, events ++ [object [
        ("action", str a.label), ("state", str after.label),
        ("actor", str (if owner before = .merchant then "Merchant" else "Customer / provider"))]]))
    (Node.checkout, [])
  return object [
    ("level", toJson (levelNumber level)), ("title", str level.title),
    ("node", str s.id), ("state", str s.label),
    ("actor", str (if owner s = .merchant then "Merchant" else "Customer / provider")),
    ("safe", jsonBool (decide (Safe s))), ("settled", jsonBool (decide (Goal s))),
    ("canForce", jsonBool (wins 8 level s)),
    ("initialCanForce", jsonBool (wins 8 level .checkout)),
    ("actions", toJson ((enabled level s).map (actionJson level s))),
    ("history", toJson history), ("moves", toJson (moves.map Action.id)),
    ("theorem", str (if level = .broken then "broken_no_strategy" else
      if level = .repaired then "repaired_has_strategy" else
      if level = .simple then "simple_wins + wins_sound" else "cancellation_wins + wins_sound")),
    ("scope", str "One order; explicit turns; atomic actions; every listed provider response is covered. No unlimited delays, retries, live payments, or hidden state. Rule text is rendered from the model; editable CNL is a later step.")]

def command (args : List String) : Except String Json := do
  match args with
  | ["play", level, actions] => snapshot (← parseLevel level) (← parseActions actions)
  | ["play", level] => snapshot (← parseLevel level) []
  | [] | ["demo"] =>
      let states ← ([Level.simple, .cancellation, .broken, .repaired]).mapM fun l => snapshot l []
      return object [("levels", toJson states)]
  | _ => throw "Usage: order_game demo | order_game play <1..4> [comma-separated actions]"

def main (args : List String) : IO UInt32 := do
  match command args with
  | .ok response => IO.println response.compress; return 0
  | .error message => IO.println (object [("error", str message)]).compress; return 1
