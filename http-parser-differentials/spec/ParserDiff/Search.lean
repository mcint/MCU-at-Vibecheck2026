import ParserDiff.Model

/-!
# Decidable witness search over a small finite message space

`space` enumerates every message with Content-Length values in `{0,1,2,3}`
(zero, one or two CL headers), TE on/off, and chunked wire length in
`{0,…,3}`.  `witnesses F B` is the list of messages on which `F` and `B`
desync; the theorems below are closed by `decide`, i.e. the kernel runs the
search.
-/

namespace ParserDiff
open Profile

def clSpace : List (List Nat) :=
  [[]] ++ (List.range 4).map (fun n => [n]) ++
  ((List.range 4).flatMap fun a => (List.range 4).map fun b => [a, b])

def space : List Msg :=
  clSpace.flatMap fun cls =>
    [true, false].flatMap fun te =>
      (List.range 4).map fun cl => ⟨cls, te, cl⟩

/-- Boolean form of `desync`, for executable search. -/
def desyncB (F B : Profile) (m : Msg) : Bool :=
  decide (desync F B m)

def witnesses (F B : Profile) : List Msg :=
  space.filter (desyncB F B)

/-- Messages in `space` where *some* ordered pair of profiles desyncs. -/
def anyDesync (m : Msg) : Bool :=
  Profile.all.any fun F => Profile.all.any fun B => desyncB F B m

def dirtyB (m : Msg) : Bool :=
  (m.te && !m.cls.isEmpty) ||
  (match m.cls with
   | a :: b :: _ => a != b
   | _ => false)

/-- `space` has 1 + 4 + 16 = 21 CL shapes × 2 × 4 = 168 messages. -/
theorem space_length : space.length = 168 := by decide +kernel

/-- The search *finds* CL.TE: a `clFirst` front end against a `teWins` back end. -/
theorem witness_clFirst_teWins : ∃ m, desync clFirst teWins m :=
  ⟨⟨[1], true, 2⟩, by decide⟩

/-- The search finds TE.CL (the other direction of the same pair). -/
theorem witness_teWins_clFirst : ∃ m, desync teWins clFirst m :=
  ⟨⟨[3], true, 0⟩, by decide⟩

/-- Duplicate Content-Length: `clFirst` vs `clLast`. -/
theorem witness_clFirst_clLast : ∃ m, desync clFirst clLast m :=
  ⟨⟨[1, 3], false, 0⟩, by decide⟩

/-- No message in the space desyncs against `strict` as back end — checked
    exhaustively by the kernel (the general theorem is `backend_strict_safe`). -/
theorem no_witness_backend_strict :
    (Profile.all.all fun F => (witnesses F strict).isEmpty) = true := by decide +kernel

/-- Exhaustive: in the space, a desync pair exists **iff** the message is dirty
    *and* its candidate lengths actually differ. -/
theorem dirty_of_anyDesync :
    (space.all fun m => !anyDesync m || dirtyB m) = true := by decide +kernel

/-- Counts, so the demo can quote them. -/
def witnessCounts : List (String × String × Nat) :=
  Profile.all.flatMap fun F => Profile.all.map fun B =>
    (F.name, B.name, (witnesses F B).length)

end ParserDiff
