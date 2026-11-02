import Chess.Model

namespace Chess

/-- Build a position from Nat row/col if both are in [0,7]. -/
def mkPos? (r c : Nat) : Option Pos :=
  if hr : r < 8 then
    if hc : c < 8 then
      some { row := ⟨r, hr⟩, col := ⟨c, hc⟩ }
    else
      none
  else
    none

/-- Piece attack geometry from `fromPos` to `target`.
    This is attack logic, not full move legality:
    - pawn uses diagonal attack only
    - king uses one-square attack only (no castling here) -/
def pieceAttacksSquare (board : Board) (cp : ColourPiece) (fromPos target : Pos) : Bool :=
  let dc := posDist target.col fromPos.col
  let dr := posDist target.row fromPos.row
  match cp.piece with
  | .pawn =>
      match cp.colour with
      | .white => dr == 1  && dc.natAbs == 1
      | .black => dr == -1 && dc.natAbs == 1
  | .knight =>
      isValidKnightMove fromPos target
  | .bishop =>
      isValidBishopMove board fromPos target
  | .rook =>
      isValidRookMove board fromPos target
  | .queen =>
      isValidQueenMove board fromPos target
  | .king =>
      dc.natAbs ≤ 1 && dr.natAbs ≤ 1 && (dc != 0 || dr != 0)

/-- Is `target` attacked by any piece of colour `attacker` on `board`? -/
def isSquareAttacked (board : Board) (attacker : Colour) (target : Pos) : Bool :=
  let rec loop (i fuel : Nat) : Bool :=
    match fuel with
    | 0 => false
    | fuel' + 1 =>
      let r := i / 8
      let c := i % 8
      match mkPos? r c with
      | none => loop (i + 1) fuel'
      | some fromPos =>
        match board.getSquare fromPos with
        | some cp =>
            if cp.colour == attacker && pieceAttacksSquare board cp fromPos target then
              true
            else
              loop (i + 1) fuel'
        | none =>
            loop (i + 1) fuel'
  loop 0 64

/-- Find the king position for a given colour, if present. -/
def findKing (board : Board) (colour : Colour) : Option Pos :=
  let rec loop (i fuel : Nat) : Option Pos :=
    match fuel with
    | 0 => none
    | fuel' + 1 =>
      let r := i / 8
      let c := i % 8
      match mkPos? r c with
      | none => loop (i + 1) fuel'
      | some p =>
        match board.getSquare p with
        | some cp =>
            if cp.colour == colour && cp.piece == .king then
              some p
            else
              loop (i + 1) fuel'
        | none =>
            loop (i + 1) fuel'
  loop 0 64

/-- Is the given colour currently in check in `state`? -/
def isInCheck (state : GameState) (colour : Colour) : Bool :=
  match findKing state.board colour with
  | none      => false
  | some kPos => isSquareAttacked state.board colour.opponent kPos

/-- True iff this move is a castling king move (2 files horizontally). -/
def isCastlingMove (move : Move) : Bool :=
  let fromPos := move.colourPiecePos.pos
  let toPos := move.toPos
  let dc := posDist toPos.col fromPos.col
  move.colourPiecePos.colourPiece.piece == .king &&
  fromPos.row == toPos.row &&
  dc.natAbs == 2

/-- Check that the expected rook is present for a castling move. -/
def hasCastlingRook (state : GameState) (move : Move) : Bool :=
  let fromPos := move.colourPiecePos.pos
  let toPos := move.toPos
  let mover := move.colourPiecePos.colourPiece.colour
  let dc := posDist toPos.col fromPos.col
  let rookCol : Fin 8 := if dc == 2 then ⟨7, by omega⟩ else ⟨0, by omega⟩
  let rookPos : Pos := { row := fromPos.row, col := rookCol }
  match state.board.getSquare rookPos with
  | some cp => cp.piece == .rook && cp.colour == mover
  | none    => false

/-- Additional castling safety:
    - king is not currently in check
    - king's transit square is not attacked
    - expected rook exists on home corner -/
def castlePathSafe (state : GameState) (move : Move) : Bool :=
  if !isCastlingMove move then
    true
  else
    let fromPos := move.colourPiecePos.pos
    let toPos := move.toPos
    let mover := move.colourPiecePos.colourPiece.colour
    let opp := mover.opponent
    let dc := posDist toPos.col fromPos.col
    let step : Int := if dc > 0 then 1 else -1
    let midColInt : Int := (fromPos.col.val : Int) + step
    match intToFin8 midColInt with
    | none => false
    | some midCol =>
      let midPos : Pos := { row := fromPos.row, col := midCol }
      hasCastlingRook state move &&
      !isSquareAttacked state.board opp fromPos &&
      !isSquareAttacked state.board opp midPos

/-- Full legal move:
    - pseudo-legal geometry/rules
    - own king safe after move
    - castling transit/start constraints -/
def isLegalMove (state : GameState) (move : Move) : Bool :=
  let pseudo := isPseudoLegalMove state move
  if !pseudo then
    false
  else
    let newState := state.makeMove move
    let kingSafeAfter := !isInCheck newState state.turn
    let castleExtra := if isCastlingMove move then castlePathSafe state move else true
    kingSafeAfter && castleExtra

/-- All board positions on an 8x8 board. -/
def allPos : List Pos :=
  (List.range 64).filterMap (fun i => mkPos? (i / 8) (i % 8))

/-- Build a move from a board square (if occupied) to a destination. -/
def mkMoveFromBoard? (state : GameState) (fromPos toPos : Pos) : Option Move :=
  match state.board.getSquare fromPos with
  | none => none
  | some cp =>
      some {
        colourPiecePos := { colourPiece := cp, pos := fromPos }
        toPos := toPos
      }

/-- Does `colour` have at least one legal move from this position? -/
def hasAnyLegalMove (state : GameState) (colour : Colour) : Bool :=
  let s' : GameState := { state with turn := colour }
  allPos.any (fun fromPos =>
    allPos.any (fun toPos =>
      match mkMoveFromBoard? s' fromPos toPos with
      | none => false
      | some m => isLegalMove s' m))

/-- Checkmate: side to test is in check and has no legal move. -/
def isCheckmate (state : GameState) (colour : Colour) : Bool :=
  isInCheck state colour && !hasAnyLegalMove state colour

/-- Game-over characterization (currently: either side is checkmated). -/
def isGameOver (state : GameState) : Bool :=
  isCheckmate state .white || isCheckmate state .black

end Chess
