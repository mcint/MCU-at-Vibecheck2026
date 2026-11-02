/-!
# HTTP/1.1 message framing — a minimal model of parser *profiles*

A request, as far as framing (RFC 9112 §6.3) is concerned, is reduced to
three facts about its header block plus one fact about the wire:

* `cls`        — the list of `Content-Length` values, in header order
                 (`[]` = absent, `[5]` = one header, `[5,7]` = duplicates);
* `te`         — whether `Transfer-Encoding: chunked` is present;
* `chunkedLen` — how many wire bytes the body occupies *if* it is read as a
                 chunked body (up to and including the `0\r\n\r\n` terminator).

A **profile** is a rule turning those facts into a body length (how many bytes
after the header block belong to *this* request) or a rejection.  Everything
after the framed body is "the next request" — which is exactly where a smuggled
request lives when two hops disagree.
-/

namespace ParserDiff

structure Msg where
  cls        : List Nat
  te         : Bool
  chunkedLen : Nat
  deriving DecidableEq, Repr

/-- How an implementation resolves framing.  Names describe the *rule*; the
    README maps them to real implementations (HAProxy / Go / h11 behave like
    `strict`, pre-RFC-7230 code like `clFirst` or `clLast`, …). -/
inductive Profile where
  /-- RFC 9112 §6.3 with every MAY-reject taken: reject CL+TE, reject
      differing duplicate CL, otherwise TE ⇒ chunked, CL ⇒ CL, none ⇒ 0. -/
  | strict
  /-- RFC 9112 §6.3 literal: "Transfer-Encoding overrides Content-Length";
      CL+TE is *not* rejected.  Duplicate differing CL rejected. -/
  | teWins
  /-- Legacy: if any Content-Length is present it wins (TE ignored);
      first duplicate taken.  The classic CL.TE back end. -/
  | clFirst
  /-- Legacy: Content-Length wins; *last* duplicate taken. -/
  | clLast
  deriving DecidableEq, Repr

open Profile

def Profile.all : List Profile := [strict, teWins, clFirst, clLast]

def Profile.name : Profile → String
  | strict  => "strict"
  | teWins  => "teWins"
  | clFirst => "clFirst"
  | clLast  => "clLast"

/-- Every element of the list equals `n`. -/
def allEq (n : Nat) : List Nat → Bool
  | []      => true
  | x :: xs => (x == n) && allEq n xs

/-- Content-Length resolution when duplicates must agree (RFC 9110 §8.6):
    absent ⇒ 0, all equal ⇒ that value, differing ⇒ reject. -/
def clStrict : List Nat → Option Nat
  | []      => some 0
  | n :: ns => if allEq n ns then some n else none

def clFirstVal : List Nat → Option Nat
  | []     => some 0
  | n :: _ => some n

def clLastVal : List Nat → Option Nat
  | []      => some 0
  | n :: ns => some (ns.getLast?.getD n)

/-- The framing decision: `some k` = the body is the next `k` wire bytes;
    `none` = the profile rejects the message (400 / connection close). -/
def frame : Profile → Msg → Option Nat
  | strict, m =>
      if m.te then (if m.cls.isEmpty then some m.chunkedLen else none)
      else clStrict m.cls
  | teWins, m =>
      if m.te then some m.chunkedLen else clStrict m.cls
  | clFirst, m =>
      match m.cls with
      | []     => if m.te then some m.chunkedLen else some 0
      | n :: _ => some n
  | clLast, m =>
      match m.cls with
      | []      => if m.te then some m.chunkedLen else some 0
      | n :: ns => some (ns.getLast?.getD n)

def accepts (p : Profile) (m : Msg) : Prop := (frame p m).isSome = true

instance (p : Profile) (m : Msg) : Decidable (accepts p m) := by
  unfold accepts; infer_instance

/-- **Desync**: front end `F` and back end `B` both accept the bytes but
    frame the body differently — the precondition of request smuggling. -/
def desync (F B : Profile) (m : Msg) : Prop :=
  frame F m ≠ frame B m ∧ accepts F m ∧ accepts B m

instance (F B : Profile) (m : Msg) : Decidable (desync F B m) := by
  unfold desync; infer_instance

/-- All body lengths that *some* reading of the headers could justify:
    the chunked length if TE is present, every CL value, and 0 if there is
    nothing at all.  Every profile picks from this menu (`frame_mem_readings`). -/
def readings (m : Msg) : List Nat :=
  (if m.te then [m.chunkedLen] else []) ++ m.cls ++
  (if !m.te && m.cls.isEmpty then [0] else [])

/-- A message with no framing ambiguity in its headers: not both CL and TE,
    and all Content-Length values agree. -/
def clean (m : Msg) : Prop :=
  (m.te = false ∨ m.cls = []) ∧
  (∀ a ∈ m.cls, ∀ b ∈ m.cls, a = b)

/-- `B` refines `F`: whenever `B` accepts, `F` accepts *with the same framing*.
    The stricter profile sits below in this order. -/
def refines (B F : Profile) : Prop :=
  ∀ m n, frame B m = some n → frame F m = some n

end ParserDiff
