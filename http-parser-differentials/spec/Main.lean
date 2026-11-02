import ParserDiff

/-!
`pd` — print, for one message, how every profile frames it.

    pd --cl 5 --cl 7 --te --chunked 12        # header facts given directly
    printf 'POST / HTTP/1.1\r\n...' | pd      # or a raw HTTP/1.1 request on stdin
    pd --witnesses clFirst teWins             # dump the decided witness list
    pd --matrix                               # desync-witness counts for all pairs

Output: one JSON object per line, e.g.
    {"profile":"strict","accept":false,"body_len":null}
-/

open ParserDiff Profile

def optJson : Option Nat → String
  | none   => "null"
  | some n => toString n

def q (s : String) : String := "\"" ++ s ++ "\""

def msgJson (m : Msg) : String :=
  "{" ++ q "cls" ++ ":[" ++ ",".intercalate (m.cls.map toString) ++ "]," ++
  q "te" ++ ":" ++ toString m.te ++ "," ++
  q "chunkedLen" ++ ":" ++ toString m.chunkedLen ++ "}"

def fieldJson : Option Field → String
  | none   => "null"
  | some f => q f.name

def profileLine (m : Msg) (p : Profile) : String :=
  let f := frame p m
  "{" ++ q "profile" ++ ":" ++ q p.name ++ "," ++
  q "accept" ++ ":" ++ toString f.isSome ++ "," ++
  q "body_len" ++ ":" ++ optJson f ++ "," ++
  q "decisive" ++ ":" ++ fieldJson (decisive p m) ++ "}"

def parseProfile : String → Option Profile
  | "strict"  => some strict
  | "teWins"  => some teWins
  | "clFirst" => some clFirst
  | "clLast"  => some clLast
  | _ => none

def isCrlfAt (b : ByteArray) (k : Nat) : Bool :=
  k + 1 < b.size && b[k]! == 13 && b[k+1]! == 10

/-- hex digits starting at `j`; returns (value, index after). -/
partial def hexAt (b : ByteArray) (j : Nat) (acc : Nat) (any : Bool) : Option (Nat × Nat) :=
  if j < b.size then
    let c := b[j]!
    if c ≥ 48 && c ≤ 57 then hexAt b (j+1) (acc*16 + (c.toNat - 48)) true
    else if c ≥ 97 && c ≤ 102 then hexAt b (j+1) (acc*16 + (c.toNat - 87)) true
    else if c ≥ 65 && c ≤ 70 then hexAt b (j+1) (acc*16 + (c.toNat - 55)) true
    else if any then some (acc, j) else none
  else none

partial def toCrlf (b : ByteArray) (k : Nat) : Option Nat :=
  if k + 1 < b.size then
    if isCrlfAt b k then some (k+2) else toCrlf b (k+1)
  else none

/-- Wire length of a chunked body starting at `start`: `size[;ext] CRLF data CRLF`
    repeated, then `0 CRLF CRLF` (empty trailer section). `none` if incomplete. -/
partial def chunkedWireLen (b : ByteArray) (start : Nat) : Option Nat :=
  let rec go (i : Nat) : Option Nat :=
    match hexAt b i 0 false with
    | none => none
    | some (size, j) =>
      match toCrlf b j with
      | none => none
      | some dataStart =>
        if size == 0 then
          if isCrlfAt b dataStart then some (dataStart + 2 - start) else none
        else
          let after := dataStart + size
          if isCrlfAt b after then go (after + 2) else none
  go start

def lower (s : String) : String := s.map Char.toLower

def trim (s : String) : String := s.trimAscii.toString

/-- Minimal header-block reader → message facts. Header names are
    case-insensitive; `Transfer-Encoding` counts if any token is `chunked`. -/
def parseRaw (raw : ByteArray) : Option Msg := Id.run do
  let mut hdrEnd : Option Nat := none
  for i in [0:raw.size] do
    if hdrEnd.isNone && i + 3 < raw.size &&
       raw[i]! == 13 && raw[i+1]! == 10 && raw[i+2]! == 13 && raw[i+3]! == 10 then
      hdrEnd := some i
  let some he := hdrEnd | return none
  let hdrStr := String.fromUTF8! (raw.extract 0 he)
  let lines := (hdrStr.splitOn "\r\n").drop 1
  let mut cls : List Nat := []
  let mut te := false
  for l in lines do
    match l.splitOn ":" with
    | name :: rest =>
      let v : String := trim (":".intercalate rest)
      let n := lower (trim name)
      if n == "content-length" then
        match v.toNat? with
        | some k => cls := cls ++ [k]
        | none => pure ()
      else if n == "transfer-encoding" then
        if (v.splitOn ",").any (fun t => lower (trim t) == "chunked") then te := true
    | _ => pure ()
  let cl := (chunkedWireLen raw (he + 4)).getD 0
  return some ⟨cls, te, cl⟩

partial def parseArgs : List String → Msg → Msg
  | "--cl" :: n :: rest, m => parseArgs rest { m with cls := m.cls ++ [n.toNat?.getD 0] }
  | "--te" :: rest, m => parseArgs rest { m with te := true }
  | "--chunked" :: n :: rest, m => parseArgs rest { m with chunkedLen := n.toNat?.getD 0 }
  | _ :: rest, m => parseArgs rest m
  | [], m => m

def main (args : List String) : IO UInt32 := do
  match args with
  | ["--matrix"] =>
    for (f, b, n) in witnessCounts do
      IO.println ("{" ++ q "front" ++ ":" ++ q f ++ "," ++ q "back" ++ ":" ++ q b ++ "," ++
        q "witnesses" ++ ":" ++ toString n ++ "," ++ q "space" ++ ":" ++ toString space.length ++ "}")
    return 0
  | ["--witnesses", f, b] =>
    match parseProfile f, parseProfile b with
    | some F, some B =>
      for m in witnesses F B do
        IO.println ("{" ++ q "msg" ++ ":" ++ msgJson m ++ "," ++ q "front" ++ ":" ++
          optJson (frame F m) ++ "," ++ q "back" ++ ":" ++ optJson (frame B m) ++ "}")
      return 0
    | _, _ => IO.eprintln "unknown profile"; return 2
  | _ =>
    let m ← if args.isEmpty then do
        let stdin ← IO.getStdin
        let raw ← stdin.readBinToEnd
        match parseRaw raw with
        | some m => pure m
        | none => IO.eprintln "could not find end of header block (CRLFCRLF)"; pure ⟨[], false, 0⟩
      else pure (parseArgs args ⟨[], false, 0⟩)
    IO.println ("{" ++ q "msg" ++ ":" ++ msgJson m ++ "," ++ q "readings" ++ ":[" ++
      ",".intercalate ((readings m).map toString) ++ "]}")
    for p in Profile.all do
      IO.println (profileLine m p)
    return 0
