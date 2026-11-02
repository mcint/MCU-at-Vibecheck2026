import ParserDiff.Model
import ParserDiff.Search
/-!
# The hinge: which header a profile *selectively prefers*

A desync is never "two parsers read the same thing differently"; it is two parsers
keying their framing decision on **different fields** of the same message. `decisive`
names that field. The theorem below says: whenever two profiles desync on a message,
they keyed on different fields — the divergence is always located at a hinge.
-/
namespace ParserDiff
open Profile

/-- The field a profile's framing decision rests on. -/
inductive Field where
  | te                  -- Transfer-Encoding: chunked
  | cl (idx : Nat)      -- the idx-th Content-Length header (0-based)
  | none                -- no body (neither field present)
  deriving DecidableEq, Repr

def Field.name : Field → String
  | .te     => "Transfer-Encoding"
  | .cl i   => s!"Content-Length[{i}]"
  | .none   => "none"

/-- Which field decided the framing; `Option.none` if the profile rejected. -/
def decisive : Profile → Msg → Option Field
  | strict, m =>
      if m.te then (if m.cls.isEmpty then some .te else Option.none)
      else (match m.cls with
            | [] => some .none
            | n :: ns => if allEq n ns then some (.cl 0) else Option.none)
  | teWins, m =>
      if m.te then some .te
      else (match m.cls with
            | [] => some .none
            | n :: ns => if allEq n ns then some (.cl 0) else Option.none)
  | clFirst, m =>
      match m.cls with
      | []     => some (if m.te then .te else .none)
      | _ :: _ => some (.cl 0)
  | clLast, m =>
      match m.cls with
      | []      => some (if m.te then .te else .none)
      | _ :: ns => some (.cl ns.length)

/-- `decisive` is defined exactly when `frame` is: rejection is the same event. -/
theorem decisive_isSome_iff_space :
    (space.all fun m => Profile.all.all fun p => (decisive p m).isSome == (frame p m).isSome) = true := by
  decide +kernel

/-- **The hinge theorem** (exhaustive over the 168-message space): if `F` and `B` desync
    on `m`, they keyed their decision on *different* fields. -/
theorem desync_hinge :
    (space.all fun m => Profile.all.all fun F => Profile.all.all fun B =>
      !desyncB F B m || decide (decisive F m ≠ decisive B m)) = true := by
  decide +kernel

/-- And the hinge is always one of two shapes: TE-vs-CL, or CL[i]-vs-CL[j] with i ≠ j. -/
def hingeShape : Option Field → Option Field → String
  | some .te, some (.cl _) => "TE vs CL"
  | some (.cl _), some .te => "CL vs TE"
  | some (.cl i), some (.cl j) => if i == j then "same" else "CL[i] vs CL[j]"
  | _, _ => "other"

theorem hinge_shapes :
    (space.all fun m => Profile.all.all fun F => Profile.all.all fun B =>
      !desyncB F B m || (let s := hingeShape (decisive F m) (decisive B m); s == "TE vs CL" || s == "CL vs TE" || s == "CL[i] vs CL[j]")) = true := by
  decide +kernel

end ParserDiff
