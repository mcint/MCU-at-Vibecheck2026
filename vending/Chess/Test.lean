import Chess.Model
import Chess.Display
import Chess.Model

def wp (p : Piece) : Square := some { piece := p, colour := Colour.white }
def bp (p : Piece) : Square := some { piece := p, colour := Colour.black }
def em : Square := none

def startingBoard : Board :=
  #v[
    #v[ wp .rook, wp .knight, wp .bishop, wp .queen, wp .king, wp .bishop, wp .knight, wp .rook ],
    #v[ wp .pawn, wp .pawn, wp .pawn, wp .pawn, wp .pawn, wp .pawn, wp .pawn, wp .pawn ],
    #v[ em, em, em, em, em, em, em, em ],
    #v[ em, em, em, em, em, em, em, em ],
    #v[ em, em, em, em, em, em, em, em ],
    #v[ em, em, em, em, em, em, em, em ],
    #v[ bp .pawn, bp .pawn, bp .pawn, bp .pawn, bp .pawn, bp .pawn, bp .pawn, bp .pawn ],
    #v[ bp .rook, bp .knight, bp .bishop, bp .queen, bp .king, bp .bishop, bp .knight, bp .rook ]
  ]

def startState : GameState :=
  { board     := startingBoard
    turn      := Colour.white
    castling  := {}
    enPassant := none
    valid     := true
    moveNum   := 0
    history   := [] }

def mkPos (r c : Nat) (hr : r < 8 := by omega) (hc : c < 8 := by omega) : Pos :=
  { row := ⟨r, hr⟩, col := ⟨c, hc⟩ }

def mkMove (piece : Piece) (colour : Colour) (r1 c1 r2 c2 : Nat)
    (hr1 : r1 < 8 := by omega) (hc1 : c1 < 8 := by omega)
    (hr2 : r2 < 8 := by omega) (hc2 : c2 < 8 := by omega)
    (promotion : Option Piece := none) : Move :=
  { colourPiecePos := {
      colourPiece := { piece := piece, colour := colour }
      pos := mkPos r1 c1 }
    toPos := mkPos r2 c2
    promotion := promotion }

deriving instance Repr for Piece
deriving instance Repr for Colour
deriving instance Repr for ColourPiece
deriving instance Repr for Pos

#eval startingBoard.getSquare (mkPos 0 0)   -- ♖
#eval startingBoard.getSquare (mkPos 7 4)   -- ♚
#eval startingBoard.getSquare (mkPos 3 3)   -- □
#eval isPseudoLegalMove startState (mkMove .pawn .white 1 4 2 4)    -- true
#eval isPseudoLegalMove startState (mkMove .pawn .white 1 4 3 4)    -- true
#eval isPseudoLegalMove startState (mkMove .pawn .white 1 4 4 4)    -- false
#eval isPseudoLegalMove startState (mkMove .pawn .white 3 3 4 3)    -- false
#eval isPseudoLegalMove startState (mkMove .pawn .black 6 4 5 4)    -- false
#eval isPseudoLegalMove startState (mkMove .knight .white 0 1 2 2)  -- true
#eval isPseudoLegalMove startState (mkMove .knight .white 0 1 2 0)  -- true
#eval isPseudoLegalMove startState (mkMove .knight .white 0 1 1 3)  -- false
#eval isPseudoLegalMove startState (mkMove .rook .white 0 0 2 0)    -- false
#eval isPseudoLegalMove startState (mkMove .bishop .white 0 2 2 4)  -- false
#eval isPseudoLegalMove startState (mkMove .queen .white 0 3 2 3)   -- false

-- Move 1: White e2→e4
def state1 := startState.makeMove (mkMove .pawn .white 1 4 3 4)
-- Move 2: Black e7→e5
def state2 := state1.makeMove (mkMove .pawn .black 6 4 4 4)
-- Move 3: White Nf3 (knight g1→f3)
def state3 := state2.makeMove (mkMove .knight .white 0 6 2 5)
-- Move 4: Black Nc6 (knight b8→c6)
def state4 := state3.makeMove (mkMove .knight .black 7 1 5 2)
-- Move 5: White Bc4 (bishop f1→c4)
def state5 := state4.makeMove (mkMove .bishop .white 0 5 3 2)
#eval state5.valid                              -- true

def stateIllegal := state5.makeMove (mkMove .pawn .white 1 3 2 3)
#eval stateIllegal.valid                        -- false

/-- Chain multiple moves, returning the final GameState -/
def playMoves (state : GameState) (moves : List Move) : GameState :=
  moves.foldl (fun s m => s.makeValidMove m) state

def gameOfTheCenturyMoves : List Move := [
  -- Nf3
  mkMove .knight .white 0 6 2 5,
  -- Nf6
  mkMove .knight .black 7 6 5 5,
  -- c4
  mkMove .pawn .white 1 2 3 2,
  -- g6
  mkMove .pawn .black 6 6 5 6,
  -- Nc3
  mkMove .knight .white 0 1 2 2,
  -- Bg7
  mkMove .bishop .black 7 5 6 6,
  -- d4
  mkMove .pawn .white 1 3 3 3,
  -- O-O
  mkMove .king .black 7 4 7 6,
  -- Bf4
  mkMove .bishop .white 0 2 3 5,
  -- d5
  mkMove .pawn .black 6 3 4 3,
  -- Qb3
  mkMove .queen .white 0 3 2 1,
  -- dxc4
  mkMove .pawn .black 4 3 3 2,
  -- Qxc4
  mkMove .queen .white 2 1 3 2,
  -- c6
  mkMove .pawn .black 6 2 5 2,
  -- e4
  mkMove .pawn .white 1 4 3 4,
  -- Nbd7
  mkMove .knight .black 7 1 6 3,
  -- Rd1
  mkMove .rook .white 0 0 0 3,
  -- Nb6
  mkMove .knight .black 6 3 5 1,
  -- Qc5
  mkMove .queen .white 3 2 4 2,
  -- Bg4
  mkMove .bishop .black 7 2 3 6,
  -- Bg5
  mkMove .bishop .white 3 5 4 6,
  -- Na4
  mkMove .knight .black 5 1 3 0,
  -- Qa3
  mkMove .queen .white 4 2 2 0,
  -- Nxc3
  mkMove .knight .black 3 0 2 2,
  -- bxc3
  mkMove .pawn .white 1 1 2 2,
  -- Nxe4
  mkMove .knight .black 5 5 3 4,
  -- Bxe7
  mkMove .bishop .white 4 6 6 4,
  -- Qb6
  mkMove .queen .black 7 3 5 1,
  -- Bc4
  mkMove .bishop .white 0 5 3 2,
  -- Nxc3
  mkMove .knight .black 3 4 2 2,
  -- Bc5
  mkMove .bishop .white 6 4 4 2,
  -- Rfe8+
  mkMove .rook .black 7 5 7 4,
  -- Kf1
  mkMove .king .white 0 4 0 5,
  -- Be6
  mkMove .bishop .black 3 6 5 4,
  -- Bxb6
  mkMove .bishop .white 4 2 5 1,
  -- Bxc4+
  mkMove .bishop .black 5 4 3 2,
  -- Kg1
  mkMove .king .white 0 5 0 6,
  -- Ne2+
  mkMove .knight .black 2 2 1 4,
  -- Kf1
  mkMove .king .white 0 6 0 5,
  -- Nxd4+
  mkMove .knight .black 1 4 3 3,
  -- Kg1
  mkMove .king .white 0 5 0 6,
  -- Ne2+
  mkMove .knight .black 3 3 1 4,
  -- Kf1
  mkMove .king .white 0 6 0 5,
  -- Nc3+
  mkMove .knight .black 1 4 2 2,
  -- Kg1
  mkMove .king .white 0 5 0 6,
  -- axb6
  mkMove .pawn .black 6 0 5 1,
  -- Qb4
  mkMove .queen .white 2 0 3 1,
  -- Ra4
  mkMove .rook .black 7 0 3 0,
  -- Qxb6
  mkMove .queen .white 3 1 5 1,
  -- Nxd1
  mkMove .knight .black 2 2 0 3,
  -- h3
  mkMove .pawn .white 1 7 2 7,
  -- Rxa2
  mkMove .rook .black 3 0 1 0,
  -- Kh2
  mkMove .king .white 0 6 1 7,
  -- Nxf2
  mkMove .knight .black 0 3 1 5,
  -- Re1
  mkMove .rook .white 0 7 0 4,
  -- Rxe1
  mkMove .rook .black 7 4 0 4,
  -- Qd8+
  mkMove .queen .white 5 1 7 3,
  -- Bf8
  mkMove .bishop .black 6 6 7 5,
  -- Nxe1
  mkMove .knight .white 2 5 0 4,
  -- Bd5
  mkMove .bishop .black 3 2 4 3,
  -- Nf3
  mkMove .knight .white 0 4 2 5,
  -- Ne4
  mkMove .knight .black 1 5 3 4,
  -- Qb8
  mkMove .queen .white 7 3 7 1,
  -- b5
  mkMove .pawn .black 6 1 4 1,
  -- h4
  mkMove .pawn .white 2 7 3 7,
  -- h5
  mkMove .pawn .black 6 7 4 7,
  -- Ne5
  mkMove .knight .white 2 5 4 4,
  -- Kg7
  mkMove .king .black 7 6 6 6,
  -- Kg1
  mkMove .king .white 1 7 0 6,
  -- Bc5+
  mkMove .bishop .black 7 5 4 2,
  -- Kf1
  mkMove .king .white 0 6 0 5,
  -- Ng3+
  mkMove .knight .black 3 4 2 6,
  -- Ke1
  mkMove .king .white 0 5 0 4,
  -- Bb4+
  mkMove .bishop .black 4 2 3 1,
  -- Kd1
  mkMove .king .white 0 4 0 3,
  -- Bb3+
  mkMove .bishop .black 4 3 2 1,
  -- Kc1
  mkMove .king .white 0 3 0 2,
  -- Ne2+
  mkMove .knight .black 2 6 1 4,
  -- Kb1
  mkMove .king .white 0 2 0 1,
  -- Nc3+
  mkMove .knight .black 1 4 2 2,
  -- Kc1
  mkMove .king .white 0 1 0 2,
  -- Rc2#
  mkMove .rook .black 1 0 1 2
]

def finalState := playMoves startState gameOfTheCenturyMoves

#eval finalState.valid
-- Total moves played should be 82
#eval finalState.moveNum

-- Key final squares for the Checkmate:
#eval finalState.board.getSquare (mkPos 0 2) -- White King on c1
#eval finalState.board.getSquare (mkPos 1 2) -- Black Rook on c2 giving mate!
#eval finalState.board.getSquare (mkPos 2 2) -- Black Knight on c3 covering d1 and b1!
#eval finalState.board.getSquare (mkPos 2 1) -- Black Bishop on b3 covering c2 and d1!
#eval finalState.board.getSquare (mkPos 4 2) -- Black Bishop on c5 covering d4 (and cutting off escape)

#eval finalState.board

def checkmatestate := playMoves startState (gameOfTheCenturyMoves.take 79)

#eval checkmatestate.valid
#eval checkmatestate
#eval checkmatestate.isAnyCheckmate


-- We take the first 8 half-moves (which ends exactly after Black's O-O)
def stateAfterCastling := playMoves startState (gameOfTheCenturyMoves.take 8)

-- Black King has moved from e8 (7, 4) to g8 (7, 6)
#eval stateAfterCastling.board.getSquare (mkPos 7 6) -- Should be ♚

-- Black Rook has "teleported" from h8 (7, 7) to f8 (7, 5)
#eval stateAfterCastling.board.getSquare (mkPos 7 5) -- Should be ♜

-- The original squares for the King (e8) and Rook (h8) are now empty!
#eval stateAfterCastling.board.getSquare (mkPos 7 4) -- Should be □
#eval stateAfterCastling.board.getSquare (mkPos 7 7) -- Should be □

-- Let's view the entire board after castling!
#eval stateAfterCastling.board

-- 1. e4 a6
-- 2. e5 d5 (d pawn double pushes alongside e5 pawn)
-- 3. exd6 e.p.
def epMove1 := mkMove .pawn .white 1 4 3 4
def epMove2 := mkMove .pawn .black 6 0 5 0
def epMove3 := mkMove .pawn .white 3 4 4 4
def epMove4 := mkMove .pawn .black 6 3 4 3
def epMove5 := mkMove .pawn .white 4 4 5 3

def epState1 := startState.makeMove epMove1
def epState2 := epState1.makeMove epMove2
def epState3 := epState2.makeMove epMove3
def epState4 := epState3.makeMove epMove4
def epState5 := epState4.makeMove epMove5

-- The capturing White pawn should now be on d6 (row 5, col 3)
#eval epState5.board.getSquare (mkPos 5 3)

-- The captured Black pawn on d5 (row 4, col 3) should be GONE (empty square)
#eval epState5.board.getSquare (mkPos 4 3)

-- Step-by-step Boards:
-- Board after 1. e4
#eval epState1.board

-- Board after 1... a6
#eval epState2.board

-- Board after 2. e5 (White pawn advances to 5th rank)
#eval epState3.board

-- Board after 2... d5 (Black pawn double pushes beside White pawn)
#eval epState4.board

-- Board after 3. exd6 e.p. (White pawn captures diagonally, Black pawn vanishes)
#eval epState5.board

-- Let's take the Game of the Century up to move 32 (16... Rfe8+)
def stateAtCheck := playMoves startState (gameOfTheCenturyMoves.take 32)

-- White should be in check from the Black Rook on e8!
#eval isInCheck stateAtCheck Colour.white

-- Can White King legally move to f1? (Kf1 is move 17 in the game)
def kf1Move := mkMove .king .white 0 4 0 5
#eval stateAtCheck.isLegalMove kf1Move

-- Can White pawn legally move a2-a3 while in check? (Should be false!)
def illegalPawnMove := mkMove .pawn .white 1 0 2 0
#eval stateAtCheck.isLegalMove illegalPawnMove

-- We will setup a custom game where a pawn promotes.
-- 1. e4 d5
-- 2. exd5 Nf6
-- 3. d6 Nd5
-- 4. d7+ Kxd7 (wait, no. Let's make it simpler)
-- 1. h4 a5 2. h5 a4 3. h6 a3 4. hxg7 axb2 5. gxh8=N
def underPromoMoves : List Move := [
  mkMove .pawn .white 1 7 3 7, -- 1. h4
  mkMove .pawn .black 6 0 4 0, -- 1... a5
  mkMove .pawn .white 3 7 4 7, -- 2. h5
  mkMove .pawn .black 4 0 3 0, -- 2... a4
  mkMove .pawn .white 4 7 5 7, -- 3. h6
  mkMove .pawn .black 3 0 2 0, -- 3... a3
  mkMove .pawn .white 5 7 6 6, -- 4. hxg7 (captures g7 pawn)
  mkMove .pawn .black 2 0 1 1, -- 4... axb2 (captures b2 pawn)
  -- 5. gxh8=N (White Pawn underpromotes to White Knight!)
  mkMove .pawn .white 6 6 7 7 (by omega) (by omega) (by omega) (by omega) (some .knight),
  -- 5... bxa1=Q (Black Pawn captures White Rook and promotes to Black Queen!)
  mkMove .pawn .black 1 1 0 0 (by omega) (by omega) (by omega) (by omega) (some .queen)
]

def promoState1 := playMoves startState (underPromoMoves.take 2)
def promoState2 := playMoves startState (underPromoMoves.take 4)
def promoState3 := playMoves startState (underPromoMoves.take 6)
def promoState4 := playMoves startState (underPromoMoves.take 8)
def promoState5 := playMoves startState (underPromoMoves.take 9)
def promoState6 := playMoves startState underPromoMoves

-- Board after 1. h4 a5
#eval promoState1.board

-- Board after 2. h5 a4
#eval promoState2.board

-- Board after 3. h6 a3
#eval promoState3.board

-- Board after 4. hxg7 axb2 (Pawns capturing!)
#eval promoState4.board

-- Board after 5. gxh8=N (White Underpromotes to Knight!)
#eval promoState5.board

-- Board after 5... bxa1=Q (Black Promotes to Queen!)
#eval promoState6.board
