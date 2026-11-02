/-- The pieces on a chessboard. -/
inductive Piece where
  | pawn
  | rook
  | knight
  | bishop
  | queen
  | king
deriving BEq

/-- The colour of a piece. -/
inductive Colour where
  | black
  | white
deriving BEq, DecidableEq

structure ColourPiece where
  piece  : Piece
  colour : Colour

abbrev Square := Option ColourPiece

abbrev Board := Vector (Vector Square 8) 8

structure Pos where
  row : Fin 8
  col : Fin 8
deriving BEq

structure ColourPiecePos where
  colourPiece : ColourPiece
  pos : Pos

structure SquarePos where
  square : Square
  pos : Pos

def Board.getSquare (board: Board) (pos: Pos) : Square :=
  (board.get pos.row).get pos.col

def Board.setSquare (board: Board) (pos: Pos) (square: Square) : Board :=
  board.set pos.row ((board.get pos.row).set pos.col square)

structure Move where
  colourPiecePos : ColourPiecePos
  toPos : Pos
  promotion : Option Piece := none

/-- Applies a move by moving whatever is at `fromPos` to `toPos`, leaving `fromPos` empty.
    Note: This does not validate if the move is legal according to chess rules. -/
def Board.forceMove (board : Board) (move : Move) : Board :=
  let piece := move.colourPiecePos.colourPiece
  let promotedPiece := match move.promotion with
    | some p => { piece with piece := p }
    | none => piece
  let boardWithoutPiece := board.setSquare move.colourPiecePos.pos none
  boardWithoutPiece.setSquare move.toPos (some promotedPiece)

/-- Tracks whether castling is still allowed for each side. -/
structure CastlingRights where
  whiteKingSide  : Bool := true
  whiteQueenSide : Bool := true
  blackKingSide  : Bool := true
  blackQueenSide : Bool := true

/-- The complete state needed to validate a move. -/
structure GameState where
  board     : Board
  turn      : Colour
  castling  : CastlingRights
  enPassant : Option (Fin 8)  -- column of a pawn that just moved two steps
  valid     : Bool
  moveNum   : Nat
  history   : List Move

/-- Signed distance between two Fin 8 values. -/
def posDist (a b : Fin 8) : Int :=
  (a.val : Int) - (b.val : Int)

/-- Try to create a Fin 8 from an Int, returning none if out of bounds. -/
def intToFin8 (n : Int) : Option (Fin 8) :=
  if h : 0 ≤ n ∧ n < 8 then
    some ⟨n.toNat, by omega⟩
  else
    none

/-- Ensures a piece isn't landing on a square occupied by its own colour. -/
def isValidTarget (board : Board) (colour : Colour) (toPos : Pos) : Bool :=
  match board.getSquare toPos with
  | none    => true
  | some cp => cp.colour != colour

def getDists (fromPos toPos : Pos) : Int × Int :=
  let dr := posDist toPos.row fromPos.row
  let dc := posDist toPos.col fromPos.col
  (dr, dc)

def isStraight (fromPos toPos : Pos) : Bool :=
  let (dr, dc) := getDists fromPos toPos
  (dc == 0 || dr == 0)

def isDiagonal (fromPos toPos : Pos) : Bool :=
  let (dr, dc) := getDists fromPos toPos
  (dc.natAbs == dr.natAbs && dc != 0)

def isStraightOrDiagonal (fromPos toPos : Pos) : Bool :=
  (isStraight fromPos toPos) || (isDiagonal fromPos toPos)

/-- Check if all squares strictly between fromPos and toPos are empty.
    The square at toPos can be non-empty (a capture move). -/
def isPathClear (board : Board) (fromPos toPos : Pos) : Bool :=
  if !(isStraightOrDiagonal fromPos toPos) then
    false
  else
    let (dr, dc) := getDists fromPos toPos
    let stepC : Int := if dc > 0 then 1 else if dc < 0 then -1 else 0
    let stepR : Int := if dr > 0 then 1 else if dr < 0 then -1 else 0
    let steps := max dc.natAbs dr.natAbs
    if steps ≤ 1 then true
    else
      let rec loop (i : Nat) (fuel : Nat) : Bool :=
        match fuel with
        | 0 => true
        | fuel' + 1 =>
          if i ≥ steps then true
          else
            let c := (fromPos.col.val : Int) + stepC * i
            let r := (fromPos.row.val : Int) + stepR * i
            match intToFin8 c, intToFin8 r with
            | some cf, some rf =>
              match board.getSquare { col := cf, row := rf } with
              | some _ => false
              | none   => loop (i + 1) fuel'
            | _, _ => false
      loop 1 7  -- at most 7 intermediate squares on an 8×8 board

def isValidKnightMove (fromPos toPos : Pos) : Bool :=
  let dc := (posDist toPos.col fromPos.col).natAbs
  let dr := (posDist toPos.row fromPos.row).natAbs
  (dc == 2 && dr == 1) || (dc == 1 && dr == 2)

def isValidRookMove (board : Board) (fromPos toPos : Pos) : Bool :=
  let dc := posDist toPos.col fromPos.col
  let dr := posDist toPos.row fromPos.row
  (dc == 0 || dr == 0) && isPathClear board fromPos toPos

def isValidBishopMove (board : Board) (fromPos toPos : Pos) : Bool :=
  let dc := (posDist toPos.col fromPos.col).natAbs
  let dr := (posDist toPos.row fromPos.row).natAbs
  dc == dr && dc != 0 && isPathClear board fromPos toPos

def isValidQueenMove (board : Board) (fromPos toPos : Pos) : Bool :=
  isValidRookMove board fromPos toPos || isValidBishopMove board fromPos toPos

def isValidKingMove (state : GameState) (fromPos toPos : Pos) : Bool :=
  let dc := posDist toPos.col fromPos.col
  let dr := posDist toPos.row fromPos.row
  if dc.natAbs ≤ 1 && dr.natAbs ≤ 1 && (dc != 0 || dr != 0) then true
  else if dc.natAbs == 2 && dr == 0 then
    let baseRow : Fin 8 := match state.turn with | .white => ⟨0, by omega⟩ | .black => ⟨7, by omega⟩
    if fromPos.col.val == 4 && fromPos.row == baseRow then
      if dc == 2 then  -- kingside
        let allowed := match state.turn with
          | .white => state.castling.whiteKingSide
          | .black => state.castling.blackKingSide
        allowed && isPathClear state.board fromPos { col := ⟨7, by omega⟩, row := baseRow }
      else  -- dc == -2, queenside
        let allowed := match state.turn with
          | .white => state.castling.whiteQueenSide
          | .black => state.castling.blackQueenSide
        allowed && isPathClear state.board fromPos { col := ⟨0, by omega⟩, row := baseRow }
    else false
  else false

def validPawnMoveHelper (move : Int × Int) (isUp : Bool) : Bool :=
  let dir := if isUp then
    (1,2)
  else
    (-1,-2)
  (move == (dir.2,0)) || (move == (dir.1,0)) || (move == (dir.1,dir.1))

def isSquareEmpty (board : Board) (pos : Pos) : Bool :=
  (board.getSquare pos).isNone

/-- Valid pawn moves:
    • 1 square forward into an empty square
    • 2 squares forward from the starting row, if both squares ahead are empty
    • 1 square diagonally forward to capture an enemy piece
    • 1 square diagonally forward for en passant (target square empty, but enemy
      pawn is beside us and just double-stepped) -/
def isValidPawnMove (state : GameState) (move : Move) : Bool :=
  let fromPos := move.colourPiecePos.pos
  let toPos := move.toPos
  let dc := posDist toPos.col fromPos.col   -- column delta
  let dr := posDist toPos.row fromPos.row   -- row delta
  let forward : Int := match state.turn with | .white => 1  | .black => -1
  let homeRow : Nat  := match state.turn with | .white => 1  | .black => 6
  let promoRow : Nat := match state.turn with | .white => 7  | .black => 0

  let validPromo := if toPos.row.val == promoRow then
    match move.promotion with
    | some p => p == .queen || p == .rook || p == .bishop || p == .knight
    | none => false
  else
    move.promotion.isNone

  if !validPromo then false else
  match dc, dr with
  -- Single push: same column, one step forward, target must be empty
  | 0, d => if d == forward then
               isSquareEmpty state.board toPos
             -- Double push: same column, two steps forward, on home row,
             -- both the intermediate and target squares must be empty
             else if d == 2 * forward && fromPos.row.val == homeRow then
               match intToFin8 ((fromPos.row.val : Int) + forward) with
               | some midRow =>
                   isSquareEmpty state.board { row := midRow, col := fromPos.col }
                   && isSquareEmpty state.board toPos
               | none => false
             else false
  -- Diagonal capture: one column left or right, one step forward
  | _, d => if dc.natAbs == 1 && d == forward then
              match state.board.getSquare toPos with
              | some cp => cp.colour != state.turn          -- normal capture
              | none    =>                                   -- en passant
                match state.enPassant with
                | some epCol =>
                  let epRow : Nat := match state.turn with | .white => 4 | .black => 3
                  toPos.col == epCol && fromPos.row.val == epRow
                | none => false
            else false

/-- Checks if a move is pseudo-legal: correct piece geometry, path is clear,
    not capturing own piece. Does NOT check if the king is left in check. -/
def isPseudoLegalMove (state : GameState) (move : Move) : Bool :=
  match state.board.getSquare move.colourPiecePos.pos with
  | none => false
  | some cp =>
    -- Must move your own colour
    if cp.colour != state.turn then false
    -- Cannot stay in place
    else if move.colourPiecePos.pos == move.toPos then false
    -- Cannot capture your own piece
    else if !(isValidTarget state.board state.turn move.toPos) then false
    -- Piece-specific rule
    else match cp.piece with
      | Piece.pawn   => isValidPawnMove state move
      | Piece.knight => isValidKnightMove move.colourPiecePos.pos move.toPos
      | Piece.rook   => isValidRookMove state.board move.colourPiecePos.pos move.toPos
      | Piece.bishop => isValidBishopMove state.board move.colourPiecePos.pos move.toPos
      | Piece.queen  => isValidQueenMove state.board move.colourPiecePos.pos move.toPos
      | Piece.king   => isValidKingMove state move.colourPiecePos.pos move.toPos

/-- Checks if a piece can move from one position to another.
    Uses pseudo-legal validation (correct piece movement, path clear, not capturing own piece).
    Does NOT check if the move leaves the king in check. -/
def Board.canMove (board: Board) (colourPiecePos: ColourPiecePos) (destPos: Pos) : Bool :=
  let state : GameState := {
    board := board
    turn := colourPiecePos.colourPiece.colour
    castling := {}
    enPassant := none
    valid := true
    moveNum := 0
    history := [],

  }
  let move : Move := { colourPiecePos := colourPiecePos, toPos := destPos }
  isPseudoLegalMove state move

/-- Flip the turn colour. -/
def Colour.opponent : Colour → Colour
  | .white => .black
  | .black => .white

/-- Update castling rights based on which piece moved and from where.
    If a king moves, both castling rights for that colour are revoked.
    If a rook moves from its home corner, the corresponding right is revoked. -/
def updateCastlingRights (castling : CastlingRights) (piece : Piece) (colour : Colour) (fromPos : Pos) : CastlingRights :=
  match piece with
  | .king =>
    match colour with
    | .white => { castling with whiteKingSide := false, whiteQueenSide := false }
    | .black => { castling with blackKingSide := false, blackQueenSide := false }
  | .rook =>
    match colour with
    | .white =>
      if fromPos.row.val == 0 && fromPos.col.val == 7 then
        { castling with whiteKingSide := false }
      else if fromPos.row.val == 0 && fromPos.col.val == 0 then
        { castling with whiteQueenSide := false }
      else castling
    | .black =>
      if fromPos.row.val == 7 && fromPos.col.val == 7 then
        { castling with blackKingSide := false }
      else if fromPos.row.val == 7 && fromPos.col.val == 0 then
        { castling with blackQueenSide := false }
      else castling
  | _ => castling

/-- Determine the new en passant column, if any.
    Set only when a pawn double-pushes from its home row. -/
def computeEnPassant (piece : Piece) (fromPos toPos : Pos) : Option (Fin 8) :=
  match piece with
  | .pawn =>
    let dr := (posDist toPos.row fromPos.row).natAbs
    if dr == 2 then some toPos.col else none
  | _ => none

/-- Try to apply a move to the current game state.
    Returns `some newState` if the move is pseudo-legal, `none` otherwise.
    The new state has:
      • the piece moved on the board
      • the turn flipped
      • castling rights updated
      • en passant column updated
      • en passant captures handled (enemy pawn removed) -/
def GameState.makeMove (state : GameState) (move : Move) : GameState :=
  if !isPseudoLegalMove state move then
    {state with valid := false}
  else
    let fromPos := move.colourPiecePos.pos
    let toPos   := move.toPos
    let piece   := move.colourPiecePos.colourPiece

    -- 1. Move the piece on the board
    let newBoard := state.board.forceMove move

    -- 2. Handle castling: move the rook alongside the king
    let newBoard :=
      match piece.piece with
      | .king =>
        let dc := posDist toPos.col fromPos.col
        let baseRow := fromPos.row
        if dc == 2 then  -- kingside: rook h→f
          let rookFrom : Pos := { row := baseRow, col := ⟨7, by omega⟩ }
          let rookTo   : Pos := { row := baseRow, col := ⟨5, by omega⟩ }
          let rook := newBoard.getSquare rookFrom
          (newBoard.setSquare rookFrom none).setSquare rookTo rook
        else if dc == -2 then  -- queenside: rook a→d
          let rookFrom : Pos := { row := baseRow, col := ⟨0, by omega⟩ }
          let rookTo   : Pos := { row := baseRow, col := ⟨3, by omega⟩ }
          let rook := newBoard.getSquare rookFrom
          (newBoard.setSquare rookFrom none).setSquare rookTo rook
        else newBoard
      | _ => newBoard

    -- 3. Handle en passant capture: remove the enemy pawn from beside us
    let newBoard :=
      match piece.piece with
      | .pawn =>
        let dc := (posDist toPos.col fromPos.col).natAbs
        if dc == 1 && (state.board.getSquare toPos).isNone then
          newBoard.setSquare { row := fromPos.row, col := toPos.col } none
        else newBoard
      | _ => newBoard

    -- 3. Update castling rights
    let newCastling := updateCastlingRights state.castling piece.piece piece.colour fromPos

    -- 4. Compute en passant column for the next move
    let newEnPassant := computeEnPassant piece.piece fromPos toPos

    -- 5. Flip the turn
    {
      board     := newBoard
      turn      := state.turn.opponent
      castling  := newCastling
      enPassant := newEnPassant
      valid     := true
      moveNum   := state.moveNum + 1
      history   := move :: state.history
    }

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
  | none      => true   -- malformed board: treat as unsafe
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

/-- Base legal move predicate (geometry + king safety). -/
def isLegalMoveInternal (state : GameState) (move : Move) : Bool :=
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
def GameState.hasAnyLegalMove (state : GameState) (colour : Colour) : Bool :=
  let s' : GameState := { state with turn := colour }
  allPos.any (fun fromPos =>
    allPos.any (fun toPos =>
      match mkMoveFromBoard? s' fromPos toPos with
      | none => false
      | some m => isLegalMoveInternal s' m))

/-- Checkmate: side to test is in check and has no legal move. -/
def GameState.isCheckmate (state : GameState) (colour : Colour) : Bool :=
  isInCheck state colour && !state.hasAnyLegalMove colour

def GameState.isAnyCheckmate (state : GameState) : Bool :=
  state.isCheckmate .white || state.isCheckmate .black

/-- Final isLegalMove:
    - pseudo-legal geometry/rules
    - own king safe after move
    - castling transit/start constraints
    - fails if the game is already in checkmate (game over) -/
def GameState.isLegalMove (state : GameState) (move : Move) : Bool :=
  if state.isAnyCheckmate then
    false
  else
    isLegalMoveInternal state move

def GameState.makeValidMove (state : GameState) (move : Move) : GameState :=
  if !(state.isLegalMove move) then
    { state with valid := false }
  else
    state.makeMove move

/-- Chain multiple moves, returning the final GameState -/
def GameState.playMoves (state : GameState) (moves : List Move) : GameState :=
  moves.foldl (fun s m => s.makeValidMove m) state

def GameState.isValidMoves (state : GameState) (moves : List Move) : Bool :=
  match moves with
  | [] => state.valid
  | m :: ms =>
    -- If the current state is already invalid, the whole sequence is invalid.
    if !state.valid then
      false
    else
      let nextState := state.makeValidMove m
      if nextState.valid then
        nextState.isValidMoves ms
      else
        false

/--
  Takes an initial GameState and a list of moves, returning a list of
  all GameStates produced after each move is applied in order.
-/
def GameState.getStatesSequence (state : GameState) (moves : List Move) : List GameState :=
  match moves with
  | [] => []
  | m :: ms =>
    let nextState := state.makeValidMove m
    nextState :: nextState.getStatesSequence ms
