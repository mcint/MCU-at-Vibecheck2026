# parser-differentials / lean

A Lake project (Lean v4.35.0, **no Mathlib**) that uses Lean to *reason about and
bound interactions between HTTP/1.1 parsers* — specifically request-smuggling
desyncs, where a front-end and a back-end parser disagree on where a message's
body ends.

## [problem]

HTTP request smuggling (CL.TE / TE.CL / duplicate Content-Length) is a *parser
differential*: two implementations in the same request path (`client → front end
→ back end → app`) resolve message framing (RFC 9112 §6.3, RFC 9110 §8.6)
differently, so one request to the front end becomes two to the back end. We want
to (a) state the condition precisely, (b) prove when it is impossible, and (c)
exhaustively find the messages where it happens.

## [formal object]

* `Msg` — a request reduced to framing-relevant facts: `cls : List Nat` (the
  Content-Length values in header order), `te : Bool` (Transfer-Encoding chunked),
  `chunkedLen : Nat` (wire length of the chunked body).
* `Profile` — `strict | teWins | clFirst | clLast`: how an implementation resolves
  framing. `strict` = RFC 9112 with every MAY-reject taken (reject CL+TE, reject
  differing duplicate CL); the others are documented lenient behaviours.
* `frame : Profile → Msg → Option Nat` — body length, or `none` = reject.
* `desync F B m := frame F m ≠ frame B m ∧ accepts F m ∧ accepts B m`.

Theorems (`ParserDiff/Theorems.lean`, `ParserDiff/Search.lean`):

| # | name | statement |
|---|------|-----------|
| 1 | `strict_unambiguous` | `strict` accepts with length `k` ⇒ every reading of the headers = `k` |
| 2 | `no_desync_strict_strict` | `∀ m, ¬ desync strict strict m` |
| 2+ | `backend_strict_safe` / `frontend_strict_safe` | `∀ F m, ¬ desync F strict m` (and symmetric): a strict hop ⇒ no smuggling, for **every** profile/message |
| 3a | `desync_only_on_dirty` | any desync ⇒ message is not `clean` (needs CL+TE or differing dup CL) |
| 3b | `desync_clFirst_teWins_iff` | CL.TE desync ⇔ `te ∧ ∃ n ns, cls = n::ns ∧ n ≠ chunkedLen` |
| 3c | `desync_clFirst_clLast_iff` | dup-CL desync ⇔ `cls.head? ≠ cls.getLast?` |
| 3d | `witness_clFirst_teWins`, `witness_clFirst_clLast`, `no_witness_backend_strict`, `dirty_of_anyDesync` | decidable search over 168 messages, closed by `decide +kernel` |
| 4 | `refines` / `refines_no_desync` / `strict_bottom` / `refines_strict_iff` | the lattice fact: `B` stricter than `F` ⇒ desync ⊆ "F accepts, B rejects" = safe; `strict` is the bottom element |

All proofs use only `propext` / `Quot.sound` (or no axioms); **no `sorry`, no
`native_decide`**. `Tests.lean` carries `#guard` tests and the `#print axioms`
audit; `test.sh` builds everything and asserts no forbidden axiom and no `sorry`.

The `pd` executable (`Main.lean`) prints, for a message, how every profile frames
it (one JSON line each) so the web demo can show the fan-out from the proven
model. It also parses a raw HTTP/1.1 request on stdin into the three facts
(including a real chunked-body length scan — ordinary code, not part of the
proofs).

## [on screen]

`../web/index.html` steps through: the model → CL.TE → TE.CL → duplicate CL →
clean-is-safe → **make the back end strict** → the exhaustive search → a
playground. At each outcome it shows the literal Lean theorem and its
`#print axioms` line. The JS model is checked against `pd` over the whole
168-message space by `../check_mirror.py`.

## Build / test

```
lake build       # library + #guard tests + pd exe
bash test.sh     # build + smoke-test pd + axiom/sorry audit
./.lake/build/bin/pd --matrix
```
