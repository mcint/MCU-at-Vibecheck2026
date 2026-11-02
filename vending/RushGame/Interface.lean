import RushGame.Verify
import Lean.Data.Json

namespace RushGame
open Lean
private def obj := Json.mkObj
private def str := Json.str
private def boolean (b : Bool) : Json := toJson b

private def buyerJson (who : String) (order : Order) : Json := obj [
  ("id", str who), ("phase", str order.id), ("label", str order.label),
  ("coin", toJson order.coin), ("drink", boolean order.drink),
  ("refunds", toJson order.refunds), ("claimed", boolean (order.claim = 1))]

private def rules : Json := toJson ([
  obj [("rule", str "One drink: at most one buyer may hold a delivery slot."),
    ("representation", str "Reachable .repaired s →\n  s.a.claim + s.b.claim ≤ 1"),
    ("theorem", str "RushGame.repaired_capacity")],
  obj [("rule", str "BUY reserves stock before the motor starts; other buyers must wait."),
    ("representation", str "advance .repaired .credit other .buy =\n  if other.claim = 0 then some .running else none"),
    ("theorem", str "RushGame.buy_reserves_slot")],
  obj [("rule", str "A customer never receives both their refund and a drink."),
    ("representation", str "Reachable .repaired s →\n  s.a.fair ∧ s.b.fair"),
    ("theorem", str "RushGame.repaired_paid_delivery")],
  obj [("rule", str "Hold a refund while delivery is running; a delivered drink stays paid."),
    ("representation", str "replay .repaired initial freeDrink\n  = .ok ⟨.served, .idle⟩"),
    ("theorem", str "RushGame.repair_holds_refund")],
  obj [("rule", str "Retrying the same refund acknowledges it without paying again."),
    ("representation", str "Reachable .repaired s →\n  s.a.refunds ≤ 1 ∧ s.b.refunds ≤ 1"),
    ("theorem", str "RushGame.repaired_refund_once")],
  obj [("rule", str "A jam releases the delivery slot for the other buyer."),
    ("representation", str "replay .repaired initial\n  [.insertCoinA, .buyA, .insertCoinB, .askRefundA,\n   .motorJamsA, .buyB, .motorDeliversB]\n  = .ok ⟨.refunded, .served⟩"),
    ("theorem", str "RushGame.jam_releases_slot_for_other_buyer")],
  obj [("rule", str "All three promises hold together for every accepted repaired history."),
    ("representation", str "replay .repaired initial moves = .ok s → Safe s"),
    ("theorem", str "RushGame.accepted_repaired_history_safe")]
  ] : List Json)

private def settled (o : Order) : Bool :=
  match o with
  | .idle | .served | .refunded => true
  | _ => false

def snapshot (policy : Policy) (moves : List Action) : Except String Json := do
  let s ← replay policy initial moves
  let capacity := decide (s.a.claim + s.b.claim ≤ 1)
  let paid := decide (s.a.fair ∧ s.b.fair)
  let refunds := decide (s.a.refunds ≤ 1 ∧ s.b.refunds ≤ 1)
  let violations := (if capacity then [] else ["Last drink reserved twice"]) ++
    (if paid then [] else ["Drink delivered after refund"]) ++
    (if refunds then [] else ["Same refund paid twice"])
  let actionValues := (enabled policy s).map fun a =>
    match step policy s a with
    | none => obj []
    | some next => obj [("id", str a.id), ("label", str a.label),
      ("next", str next.id), ("rule", str s!"{a.label}: {s.formal} → {next.formal}")]
  return obj [
    ("scenario", str "rush"), ("level", toJson (if policy = .broken then (3 : Nat) else 4)),
    ("title", str "Rush hour: two buyers, one drink"), ("node", str s.id),
    ("formalState", str s.formal), ("formalSystem", str "RushGame"),
    ("state", str s!"A: {s.a.label}. B: {s.b.label}."),
    ("actor", str "You / dispenser"), ("machineChoice", str ""),
    ("coinWithPlayer", boolean (s.a.coin > 0)), ("drinkWithPlayer", boolean s.a.drink),
    ("safe", boolean (decide (Safe s))), ("refundProtected", boolean (decide (Safe s))),
    ("settled", boolean (settled s.a && settled s.b && !moves.isEmpty)),
    ("buyers", toJson [buyerJson "A" s.a, buyerJson "B" s.b]),
    ("claims", toJson (s.a.claim + s.b.claim)), ("stock", toJson (1 : Nat)),
    ("promises", obj [("capacity", boolean capacity), ("paidDelivery", boolean paid),
      ("refundOnce", boolean refunds)]), ("violations", toJson violations),
    ("actions", toJson actionValues), ("moves", toJson (moves.map Action.id)),
    ("businessRules", rules),
    ("counterexample", toJson (if policy = .broken then some (overbook.map Action.id) else none)),
    ("challenges", toJson ([
      obj [("title", str "Double-book the last drink"),
        ("tactic", str "Start both orders before either delivery finishes."),
        ("moves", toJson (overbook.map Action.id)), ("theorem", str "RushGame.old_double_books")],
      obj [("title", str "Refund, then late delivery"),
        ("tactic", str "Request a refund while the motor is still running, then schedule delivery."),
        ("moves", toJson (freeDrink.map Action.id)), ("theorem", str "RushGame.old_gives_free_drink")],
      obj [("title", str "Collect the same refund twice"),
        ("tactic", str "Cancel before buying, then repeat the completed refund request."),
        ("moves", toJson (duplicateRefund.map Action.id)), ("theorem", str "RushGame.old_pays_refund_twice")]
      ] : List Json)),
    ("policyTheorem", str (if policy = .repaired then "RushGame.repaired_all_promises"
      else "RushGame.old_double_books + RushGame.old_gives_free_drink + RushGame.old_pays_refund_twice")),
    ("scope", str "Two one-coin orders and one delivery slot. Slot claims include pending and fulfilled deliveries. Refund payouts use a modeled cash float; two or more payouts are abstracted as 2. Explicit interleavings and duplicate refund events are modeled; order reuse, arbitrary network payloads, and actual hardware are not.")]

def command (level input : String) : Except String Json := do
  let policy ← match level with
    | "3" => .ok Policy.broken | "4" => .ok Policy.repaired
    | _ => .error "Rush hour supports policies 3 and 4."
  let names := if input.isEmpty then [] else input.splitOn ","
  if names.length > 32 then throw "At most 32 moves are accepted."
  let actions ← names.mapM fun name =>
    match Action.all.find? (fun a => a.id == name) with
    | some a => .ok a
    | none => .error s!"Unknown rush action: {name}. No moves were applied."
  snapshot policy actions

end RushGame
