import Lean
import LeanContracts.Basic

/-!
Multi-period semantics and human-readable contract rendering.
-/

initialize Lean.registerTraceClass `PolicyContracts

namespace LeanContracts

/-- Evaluate a contract independently across a series of period contexts. -/
def evaluateMany (contexts : List Context) (contract : Contract) : List Amount :=
  contexts.map fun ctx => evaluate ctx contract

namespace Contract

/-- Evaluate a contract while collecting deterministic trace messages. -/
def evaluateTrace (ctx : Context) : Contract → List String × Amount
  | zero => (["zero => 0"], 0.0)
  | pay amount => ([s!"pay {amount} => {amount}"], amount)
  | give contract =>
      let (steps, amount) := evaluateTrace ctx contract
      (steps ++ [s!"give => {-amount}"], -amount)
  | both left right =>
      let (leftSteps, leftAmount) := evaluateTrace ctx left
      let (rightSteps, rightAmount) := evaluateTrace ctx right
      let amount := leftAmount + rightAmount
      (leftSteps ++ rightSteps ++ [s!"both => {amount}"], amount)
  | cond condition yes no =>
      match Observable.eval ctx condition with
      | true =>
          let (steps, amount) := evaluateTrace ctx yes
          ("cond true" :: steps, amount)
      | false =>
          let (steps, amount) := evaluateTrace ctx no
          ("cond false" :: steps, amount)
  | scale factor contract =>
      let scalar := Observable.eval ctx factor
      let (steps, amount) := evaluateTrace ctx contract
      let scaled := scalar * amount
      (steps ++ [s!"scale {scalar} => {scaled}"], scaled)
  | «until» deadline contract =>
      if ctx.time <= deadline then
        let (steps, amount) := evaluateTrace ctx contract
        (s!"until {deadline} active" :: steps, amount)
      else
        ([s!"until {deadline} expired => 0"], 0.0)
  | seq first second =>
      let (firstSteps, firstAmount) := evaluateTrace ctx first
      let (secondSteps, secondAmount) := evaluateTrace { ctx with time := ctx.time + 1 } second
      let amount := firstAmount + secondAmount
      (firstSteps ++ secondSteps ++ [s!"seq => {amount}"], amount)
  | when condition contract =>
      if Observable.eval ctx condition then
        let (steps, amount) := evaluateTrace ctx contract
        ("when true" :: steps, amount)
      else
        (["when false => 0"], 0.0)
  | anytime condition contract =>
      if Observable.eval ctx condition then
        let (steps, amount) := evaluateTrace ctx contract
        ("anytime true" :: steps, amount)
      else
        (["anytime false => 0"], 0.0)
  | truncate horizon contract =>
      if ctx.time <= horizon then
        let (steps, amount) := evaluateTrace ctx contract
        (s!"truncate {horizon} active" :: steps, amount)
      else
        ([s!"truncate {horizon} expired => 0"], 0.0)
termination_by contract => contract

end Contract

/-- Public traced evaluator that returns steps and the final amount. -/
def evaluateTrace : Context → Contract → List String × Amount := Contract.evaluateTrace

namespace Observable

/-- Render an observable in compact domain syntax. -/
def pp {α : Type} : Observable α → String
  | constFloat value => toString value
  | constNat value => toString value
  | constBool true => "true"
  | constBool false => "false"
  | income => "income"
  | children => "children"
  | age => "age"
  | time => "time"
  | var name => "$" ++ name
  | add left right => "(" ++ pp left ++ " + " ++ pp right ++ ")"
  | sub left right => "(" ++ pp left ++ " - " ++ pp right ++ ")"
  | mul left right => "(" ++ pp left ++ " * " ++ pp right ++ ")"
  | neg value => "(-" ++ pp value ++ ")"
  | natToFloat value => "float(" ++ pp value ++ ")"
  | ltFloat left right => pp left ++ " < " ++ pp right
  | leFloat left right => pp left ++ " <= " ++ pp right
  | gtFloat left right => pp left ++ " > " ++ pp right
  | geFloat left right => pp left ++ " >= " ++ pp right
  | eqNat left right => pp left ++ " == " ++ pp right
  | leNat left right => pp left ++ " <= " ++ pp right
  | not value => "not " ++ pp value
  | and left right => "(" ++ pp left ++ " and " ++ pp right ++ ")"
  | or left right => "(" ++ pp left ++ " or " ++ pp right ++ ")"

end Observable

/-- Pretty-print a contract in readable domain syntax. -/
def pp : Contract → String
  | Contract.zero => "zero"
  | Contract.pay amount => "pay " ++ toString amount
  | Contract.give contract => "give (" ++ pp contract ++ ")"
  | Contract.both left right => "(" ++ pp left ++ " & " ++ pp right ++ ")"
  | Contract.cond condition yes no =>
      "if " ++ Observable.pp condition ++ " then " ++ pp yes ++ " else " ++ pp no
  | Contract.scale factor contract =>
      "scale " ++ Observable.pp factor ++ " (" ++ pp contract ++ ")"
  | Contract.«until» deadline contract =>
      "until " ++ toString deadline ++ " (" ++ pp contract ++ ")"
  | Contract.seq first second => pp first ++ " ; " ++ pp second
  | Contract.when condition contract =>
      "when " ++ Observable.pp condition ++ " (" ++ pp contract ++ ")"
  | Contract.anytime condition contract =>
      "anytime " ++ Observable.pp condition ++ " (" ++ pp contract ++ ")"
  | Contract.truncate horizon contract =>
      "truncate " ++ toString horizon ++ " (" ++ pp contract ++ ")"

instance : ToString Contract where
  toString := pp

end LeanContracts
