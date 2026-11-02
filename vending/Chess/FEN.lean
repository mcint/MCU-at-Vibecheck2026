import Std
import Chess.Model
import Chess.Display

def charToPiece (c : Char) : Option ColourPiece :=
  match c with
  | 'p' => some ⟨.pawn, .black⟩   | 'P' => some ⟨.pawn, .white⟩
  | 'r' => some ⟨.rook, .black⟩   | 'R' => some ⟨.rook, .white⟩
  | 'n' => some ⟨.knight, .black⟩ | 'N' => some ⟨.knight, .white⟩
  | 'b' => some ⟨.bishop, .black⟩ | 'B' => some ⟨.bishop, .white⟩
  | 'q' => some ⟨.queen, .black⟩  | 'Q' => some ⟨.queen, .white⟩
  | 'k' => some ⟨.king, .black⟩   | 'K' => some ⟨.king, .white⟩
  | _   => none

def expandFenDigit (c : Char) : List Square :=
  match c with
  | '1' => List.replicate 1 none
  | '2' => List.replicate 2 none
  | '3' => List.replicate 3 none
  | '4' => List.replicate 4 none
  | '5' => List.replicate 5 none
  | '6' => List.replicate 6 none
  | '7' => List.replicate 7 none
  | '8' => List.replicate 8 none
  | _   => []

/-- Parses a single rank and proves it has length 8 -/
def parseRankToVector (s : String) : Option (Vector Square 8) :=
  let rec loop (chars : List Char) : List Square :=
    match chars with
    | [] => []
    | c :: cs =>
      if c.isDigit then expandFenDigit c ++ loop cs
      else charToPiece c :: loop cs
  let l := loop s.toList
  if h : l.length = 8 then
    some ⟨l.toArray, h⟩
  else
    none

def parseBoardToVector (s : String) : Option Board :=
  let rankStrings := s.splitOn "/"
  let maybeRanks := rankStrings.map parseRankToVector
  let rec extract (l : List (Option (Vector Square 8))) : Option (List (Vector Square 8)) :=
    match l with
    | [] => some []
    | some r :: rs => (extract rs).map (fun res => r :: res)
    | none :: _ => none

  match extract maybeRanks with
  | some res =>
    if h : res.length = 8 then
      some ⟨res.toArray, h⟩
    else none
  | none => none

def parseCastling (s : String) : CastlingRights :=
  { whiteKingSide  := s.contains 'K'
    whiteQueenSide := s.contains 'Q'
    blackKingSide  := s.contains 'k'
    blackQueenSide := s.contains 'q' }

def parseEnPassant (s : String) : Option (Fin 8) :=
  match s.toList with
  | col :: _row :: [] =>
    let c := col.toLower
    let val := c.toNat - 'a'.toNat
    if h : val < 8 then some ⟨val, h⟩ else none
  | _ => none

def emptyBoard : Board :=
  let row : Vector Square 8 := ⟨List.replicate 8 none |>.toArray, rfl⟩
  ⟨List.replicate 8 row |>.toArray, rfl⟩

def fenToGameState (fen : String) : GameState :=
  let parts := fen.splitOn " "
  match parts with
  | [boardPart, turnPart, castlingPart, epPart, _half, full] =>
    match parseBoardToVector boardPart with
    | some board =>
      { board     := board
        turn      := if turnPart == "w" then .white else .black
        castling  := parseCastling castlingPart
        enPassant := parseEnPassant epPart
        valid     := true
        moveNum   := full.toNat!
        history   := [] }
    | none =>
      { board := emptyBoard, turn := .white, castling := {},
        enPassant := none, valid := false, moveNum := 0, history := [] }
  | _ =>
    { board := emptyBoard, turn := .white, castling := {},
      enPassant := none, valid := false, moveNum := 0, history := [] }

--#eval fenToGameState "r2k2nr/pp1b1Q1p/2n4b/3N4/3q4/3P4/PPP3PP/4RR1K w - - 1 0"
