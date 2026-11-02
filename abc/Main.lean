import Abc
open Abc

/-! REPL over the proven rules.
  lake exe abc [abc|abc-1] [N] [a,b,c]      play. keys: a b c · u undo · r redo · ? best-from-here · ! best line · q
  lake exe abc traj [abc|abc-1] PLAY [a,b,c]  print CSV trajectory (t,a,b,c,score,alive) — feeds plots/ -/

def parseVariant : String → Variant
  | "abc-1" => .nosat | "nosat" => .nosat | _ => .sat

def parseSt (s : String) : Option St :=
  match s.splitOn "," |>.map String.toInt? with
  | [some a, some b, some c] => some ⟨a, b, c⟩
  | _ => none

structure Game where
  v      : Variant
  n      : Nat
  s0     : St
  past   : List Act := []
  future : List Act := []
  peeks  : Nat := 0

def Game.state (g : Game) : St := runFrom g.v g.s0 g.past.reverse
def Game.turn  (g : Game) : Nat := g.past.length
def Game.left  (g : Game) : Nat := g.n - g.turn

def bar (x : Int) : String :=
  if x ≤ 0 then "·" else String.ofList (List.replicate (min x.toNat 40) '#')

def render (g : Game) : String :=
  let s := g.state
  let hist := String.ofList (g.past.reverse.map Act.toChar)
  let status := if alive s then "alive" else (if g.v == .sat then "DEAD (a zero is forever)" else "SINKING (negatives double down)")
  s!"turn {g.turn}/{g.n}  a={s.a} b={s.b} c={s.c}  min={score s}  {status}  play=[{hist}] peeks={g.peeks}\n" ++
  s!"   a {bar s.a}\n   b {bar s.b}\n   c {bar s.c}"

partial def loop (g : Game) : IO Unit := do
  IO.println (render g)
  if g.left == 0 then IO.println s!"  done. min={score g.state}. (u to undo, q to quit)"
  let line ← (← IO.getStdin).getLine
  if line.isEmpty then return
  match line.toList.filter (fun c => !c.isWhitespace) with
  | [] => loop g
  | 'q' :: _ => IO.println "bye"
  | 'u' :: _ => match g.past with
    | [] => loop g
    | x :: rest => loop { g with past := rest, future := x :: g.future }
  | 'r' :: _ => match g.future with
    | [] => loop g
    | x :: rest => loop { g with past := x :: g.past, future := rest }
  | '?' :: _ =>
    IO.println s!"  oracle: best reachable min from here = {bestFrom g.v g.state g.left}"
    loop { g with peeks := g.peeks + 1 }
  | '!' :: _ =>
    IO.println s!"  oracle: a best line from here = {String.ofList ((bestPlay g.v g.state g.left).map Act.toChar)}"
    loop { g with peeks := g.peeks + 1 }
  | ch :: _ => match Act.ofChar ch with
    | none => IO.println "  keys: a b c | u undo | r redo | ? best-from-here | ! best-line | q"; loop g
    | some act => if g.left == 0 then loop g else loop { g with past := act :: g.past, future := [] }

def main (args : List String) : IO Unit := do
  match args with
  | "traj" :: vs :: play :: rest =>
    let v := parseVariant vs
    let s0 := (rest.head? >>= parseSt).getD s4
    let acts := play.toList.filterMap Act.ofChar
    IO.println "t,a,b,c,score,alive"
    for (s, t) in (traj v s0 acts).zip (List.range (acts.length + 1)) do
      IO.println s!"{t},{s.a},{s.b},{s.c},{score s},{if alive s then 1 else 0}"
  | _ =>
    let v := parseVariant (args.getD 0 "abc")
    let n := (args[1]? >>= String.toNat?).getD 9
    let s0 := (args[2]? >>= parseSt).getD s4
    IO.println s!"{if v == .sat then "abc" else "abc-1"} — {n} turns from ({s0.a},{s0.b},{s0.c}). Click one to double it; the others drop by 1. Keep the weakest alive."
    IO.println "Proven: (2,2,2) doomed in 2 moves · (3,3,3) never all above 3, ever · (4,4,4) unbounded. See Abc.lean."
    loop { v, n, s0 }
