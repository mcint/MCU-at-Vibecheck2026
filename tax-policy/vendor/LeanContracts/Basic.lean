/-!
Core combinators and denotational semantics for LeanContracts.

The library models policies and financial contracts as a small algebra of total
constructors. Evaluation is pure, structural, and independent of any runtime
parser or external service.
-/

namespace LeanContracts

/-- Monetary amount represented as a Lean `Float`. -/
abbrev Amount := Float

/-- Discrete time index used by temporal contract combinators. -/
abbrev Time := Nat

/-- A named extensibility environment for user-defined numeric observables. -/
abbrev Vars := List (String × Float)

/-- Evaluation context supplied by the caller for one period. -/
structure Context where
  /-- Current period. -/
  time : Time := 0
  /-- Household or entity income. -/
  income : Float := 0.0
  /-- Number of qualifying children. -/
  children : Nat := 0
  /-- Age of the primary person or instrument. -/
  age : Nat := 0
  /-- User-defined numeric variables. -/
  vars : Vars := []
deriving Repr, BEq

/-- Lookup a named variable from the extensibility environment. -/
def Context.var? (ctx : Context) (name : String) : Option Float :=
  ctx.vars.findSome? fun entry =>
    if entry.fst == name then some entry.snd else none

/-- Check that all floating-point values supplied by a context are finite. -/
def Context.valid (ctx : Context) : Bool :=
  ctx.income.isFinite && ctx.vars.all fun entry => entry.snd.isFinite

/-- Typed observable expressions used by contract conditions and scaling. -/
inductive Observable : Type → Type where
  | constFloat : Float → Observable Float
  | constNat : Nat → Observable Nat
  | constBool : Bool → Observable Bool
  | income : Observable Float
  | children : Observable Nat
  | age : Observable Nat
  | time : Observable Time
  | var : String → Observable Float
  | add : Observable Float → Observable Float → Observable Float
  | sub : Observable Float → Observable Float → Observable Float
  | mul : Observable Float → Observable Float → Observable Float
  | neg : Observable Float → Observable Float
  | natToFloat : Observable Nat → Observable Float
  | ltFloat : Observable Float → Observable Float → Observable Bool
  | leFloat : Observable Float → Observable Float → Observable Bool
  | gtFloat : Observable Float → Observable Float → Observable Bool
  | geFloat : Observable Float → Observable Float → Observable Bool
  | eqNat : Observable Nat → Observable Nat → Observable Bool
  | leNat : Observable Nat → Observable Nat → Observable Bool
  | not : Observable Bool → Observable Bool
  | and : Observable Bool → Observable Bool → Observable Bool
  | or : Observable Bool → Observable Bool → Observable Bool
deriving Repr

namespace Observable

/-- Evaluate an observable in a single context. Missing variables evaluate to `0`. -/
def eval {α : Type} (ctx : Context) : Observable α → α
  | constFloat value => value
  | constNat value => value
  | constBool value => value
  | income => ctx.income
  | children => ctx.children
  | age => ctx.age
  | time => ctx.time
  | var name => ctx.var? name |>.getD 0.0
  | add left right => eval ctx left + eval ctx right
  | sub left right => eval ctx left - eval ctx right
  | mul left right => eval ctx left * eval ctx right
  | neg value => - eval ctx value
  | natToFloat value => Float.ofNat (eval ctx value)
  | ltFloat left right => eval ctx left < eval ctx right
  | leFloat left right => eval ctx left <= eval ctx right
  | gtFloat left right => eval ctx left > eval ctx right
  | geFloat left right => eval ctx left >= eval ctx right
  | eqNat left right => eval ctx left == eval ctx right
  | leNat left right => eval ctx left <= eval ctx right
  | not value => !(eval ctx value)
  | and left right => eval ctx left && eval ctx right
  | or left right => eval ctx left || eval ctx right

end Observable

/-- Contract algebra for composing policies and financial instruments. -/
inductive Contract where
  | zero : Contract
  | pay : Amount → Contract
  | give : Contract → Contract
  | both : Contract → Contract → Contract
  | cond : Observable Bool → Contract → Contract → Contract
  | scale : Observable Float → Contract → Contract
  | «until» : Time → Contract → Contract
  | seq : Contract → Contract → Contract
  | when : Observable Bool → Contract → Contract
  | anytime : Observable Bool → Contract → Contract
  | truncate : Time → Contract → Contract
deriving Repr

namespace Contract

/-- Denotational single-period evaluation for a contract. -/
def evaluate (ctx : Context) : Contract → Amount
  | zero => 0.0
  | pay amount => amount
  | give contract => - evaluate ctx contract
  | both left right => evaluate ctx left + evaluate ctx right
  | cond condition yes no => if Observable.eval ctx condition then evaluate ctx yes else evaluate ctx no
  | scale factor contract => Observable.eval ctx factor * evaluate ctx contract
  | «until» deadline contract => if ctx.time <= deadline then evaluate ctx contract else 0.0
  | seq first second => evaluate ctx first + evaluate { ctx with time := ctx.time + 1 } second
  | when condition contract => if Observable.eval ctx condition then evaluate ctx contract else 0.0
  | anytime condition contract => if Observable.eval ctx condition then evaluate ctx contract else 0.0
  | truncate horizon contract => if ctx.time <= horizon then evaluate ctx contract else 0.0

end Contract

/-- Public evaluator alias. -/
def evaluate : Context → Contract → Amount := Contract.evaluate

/-- Checked evaluator that rejects invalid floating-point inputs or outputs. -/
def evaluateChecked (ctx : Context) (contract : Contract) : Except String Amount :=
  if ctx.valid then
    let amount := evaluate ctx contract
    if amount.isFinite then
      Except.ok amount
    else
      Except.error "contract evaluated to a non-finite amount"
  else
    Except.error "context contains a non-finite floating-point value"

/-- The neutral contract. -/
def zero : Contract := Contract.zero

/-- Pay a fixed amount to the holder. -/
def pay (amount : Amount) : Contract := Contract.pay amount

/-- Reverse the sign of a contract's cash flow. -/
def give (contract : Contract) : Contract := Contract.give contract

/-- Combine two contracts in the same period. -/
def both (left right : Contract) : Contract := Contract.both left right

/-- Choose between contracts using a Boolean observable. -/
def cond (condition : Observable Bool) (yes no : Contract) : Contract :=
  Contract.cond condition yes no

/-- Scale a contract by a numeric observable. -/
def scale (factor : Observable Float) (contract : Contract) : Contract :=
  Contract.scale factor contract

/-- Evaluate a contract only through a deadline. -/
def «until» (deadline : Time) (contract : Contract) : Contract :=
  Contract.«until» deadline contract

/-- Sequence two contracts by evaluating the second in the next period. -/
def seq (first second : Contract) : Contract := Contract.seq first second

/-- Pay a contract when a condition holds, otherwise pay zero. -/
def when (condition : Observable Bool) (contract : Contract) : Contract :=
  Contract.when condition contract

/-- Alias for a condition that may become true in any evaluated period. -/
def anytime (condition : Observable Bool) (contract : Contract) : Contract :=
  Contract.anytime condition contract

/-- Cut off a contract after the supplied horizon. -/
def truncate (horizon : Time) (contract : Contract) : Contract :=
  Contract.truncate horizon contract

end LeanContracts
