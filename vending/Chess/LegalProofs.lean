import Chess.Model
import Chess.Legal

namespace Chess

theorem makeMove_history_of_pseudoLegal
  (s : GameState) (m : Move)
  (h : isPseudoLegalMove s m = true) :
  (s.makeMove m).history = m :: s.history := by
  unfold GameState.makeMove
  simp [h]

theorem makeMove_turn_of_pseudoLegal
  (s : GameState) (m : Move)
  (h : isPseudoLegalMove s m = true) :
  (s.makeMove m).turn = s.turn.opponent := by
  unfold GameState.makeMove
  simp [h]

theorem makeMove_moveNum_of_pseudoLegal
  (s : GameState) (m : Move)
  (h : isPseudoLegalMove s m = true) :
  (s.makeMove m).moveNum = s.moveNum + 1 := by
  unfold GameState.makeMove
  simp [h]

theorem makeMove_validFlag_of_pseudoLegal
  (s : GameState) (m : Move)
  (h : isPseudoLegalMove s m = true) :
  (s.makeMove m).valid = true := by
  unfold GameState.makeMove
  simp [h]

theorem makeMove_validFlag_of_not_pseudoLegal
  (s : GameState) (m : Move)
  (h : isPseudoLegalMove s m = false) :
  (s.makeMove m).valid = false := by
  unfold GameState.makeMove
  simp [h]

theorem makeMove_turn_of_not_pseudoLegal
  (s : GameState) (m : Move)
  (h : isPseudoLegalMove s m = false) :
  (s.makeMove m).turn = s.turn := by
  unfold GameState.makeMove
  simp [h]

theorem makeMove_board_of_not_pseudoLegal
  (s : GameState) (m : Move)
  (h : isPseudoLegalMove s m = false) :
  (s.makeMove m).board = s.board := by
  unfold GameState.makeMove
  simp [h]

theorem makeMove_history_of_not_pseudoLegal
  (s : GameState) (m : Move)
  (h : isPseudoLegalMove s m = false) :
  (s.makeMove m).history = s.history := by
  unfold GameState.makeMove
  simp [h]

theorem makeMove_moveNum_of_not_pseudoLegal
  (s : GameState) (m : Move)
  (h : isPseudoLegalMove s m = false) :
  (s.makeMove m).moveNum = s.moveNum := by
  unfold GameState.makeMove
  simp [h]

theorem makeMove_castling_of_not_pseudoLegal
  (s : GameState) (m : Move)
  (h : isPseudoLegalMove s m = false) :
  (s.makeMove m).castling = s.castling := by
  unfold GameState.makeMove
  simp [h]

theorem makeMove_enPassant_of_not_pseudoLegal
  (s : GameState) (m : Move)
  (h : isPseudoLegalMove s m = false) :
  (s.makeMove m).enPassant = s.enPassant := by
  unfold GameState.makeMove
  simp [h]

theorem isInCheck_eq_attackedKingSquare
  (s : GameState) (c : Colour) (k : Pos)
  (h : findKing s.board c = some k) :
  isInCheck s c = isSquareAttacked s.board c.opponent k := by
  unfold isInCheck
  simp [h]

theorem castlePathSafe_implies_hasRook
  (s : GameState) (m : Move)
  (hCastle : isCastlingMove m = true)
  (hSafe : castlePathSafe s m = true) :
  hasCastlingRook s m = true := by
  let midExpr :=
    intToFin8 ((m.colourPiecePos.pos.col.val : Int) +
      (if 0 < posDist m.toPos.col m.colourPiecePos.pos.col then 1 else -1))
  cases hMid : midExpr with
  | none =>
      simp [midExpr, castlePathSafe, hCastle, hMid] at hSafe
  | some midCol =>
      have hSafe' :
          (hasCastlingRook s m &&
              !isSquareAttacked s.board m.colourPiecePos.colourPiece.colour.opponent m.colourPiecePos.pos &&
              !isSquareAttacked s.board m.colourPiecePos.colourPiece.colour.opponent
                { row := m.colourPiecePos.pos.row, col := midCol }) = true := by
        simpa [midExpr, castlePathSafe, hCastle, hMid] using hSafe
      have hDecomp :
          hasCastlingRook s m = true ∧
          !isSquareAttacked s.board m.colourPiecePos.colourPiece.colour.opponent m.colourPiecePos.pos = true ∧
          !isSquareAttacked s.board m.colourPiecePos.colourPiece.colour.opponent
            { row := m.colourPiecePos.pos.row, col := midCol } = true := by
        simpa [Bool.and_eq_true, and_assoc] using hSafe'
      exact hDecomp.1

theorem castlePathSafe_implies_startSafe
  (s : GameState) (m : Move)
  (hCastle : isCastlingMove m = true)
  (hSafe : castlePathSafe s m = true) :
  let fromPos := m.colourPiecePos.pos
  let mover := m.colourPiecePos.colourPiece.colour
  isSquareAttacked s.board mover.opponent fromPos = false := by
  dsimp
  let midExpr :=
    intToFin8 ((m.colourPiecePos.pos.col.val : Int) +
      (if 0 < posDist m.toPos.col m.colourPiecePos.pos.col then 1 else -1))
  cases hMid : midExpr with
  | none =>
      simp [midExpr, castlePathSafe, hCastle, hMid] at hSafe
  | some midCol =>
      have hSafe' :
          (hasCastlingRook s m &&
              !isSquareAttacked s.board m.colourPiecePos.colourPiece.colour.opponent m.colourPiecePos.pos &&
              !isSquareAttacked s.board m.colourPiecePos.colourPiece.colour.opponent
                { row := m.colourPiecePos.pos.row, col := midCol }) = true := by
        simpa [midExpr, castlePathSafe, hCastle, hMid] using hSafe
      have hDecomp :
          hasCastlingRook s m = true ∧
          !isSquareAttacked s.board m.colourPiecePos.colourPiece.colour.opponent m.colourPiecePos.pos = true ∧
          !isSquareAttacked s.board m.colourPiecePos.colourPiece.colour.opponent
            { row := m.colourPiecePos.pos.row, col := midCol } = true := by
        simpa [Bool.and_eq_true, and_assoc] using hSafe'
      have hStart :
          !isSquareAttacked s.board m.colourPiecePos.colourPiece.colour.opponent m.colourPiecePos.pos = true :=
        hDecomp.2.1
      simpa using hStart

theorem castlePathSafe_implies_midSafe
  (s : GameState) (m : Move)
  (hCastle : isCastlingMove m = true)
  (hSafe : castlePathSafe s m = true) :
  let fromPos := m.colourPiecePos.pos
  let toPos := m.toPos
  let mover := m.colourPiecePos.colourPiece.colour
  let dc := posDist toPos.col fromPos.col
  let step : Int := if dc > 0 then 1 else -1
  let midColInt : Int := (fromPos.col.val : Int) + step
  match intToFin8 midColInt with
  | some midCol =>
      isSquareAttacked s.board mover.opponent { row := fromPos.row, col := midCol } = false
  | none => False := by
  dsimp
  let midExpr :=
    intToFin8 ((m.colourPiecePos.pos.col.val : Int) +
      (if 0 < posDist m.toPos.col m.colourPiecePos.pos.col then 1 else -1))
  cases hMid : midExpr with
  | none =>
      simp [midExpr, castlePathSafe, hCastle, hMid] at hSafe
  | some midCol =>
      have hSafe' :
          (hasCastlingRook s m &&
              !isSquareAttacked s.board m.colourPiecePos.colourPiece.colour.opponent m.colourPiecePos.pos &&
              !isSquareAttacked s.board m.colourPiecePos.colourPiece.colour.opponent
                { row := m.colourPiecePos.pos.row, col := midCol }) = true := by
        simpa [midExpr, castlePathSafe, hCastle, hMid] using hSafe
      have hDecomp :
          hasCastlingRook s m = true ∧
          !isSquareAttacked s.board m.colourPiecePos.colourPiece.colour.opponent m.colourPiecePos.pos = true ∧
          !isSquareAttacked s.board m.colourPiecePos.colourPiece.colour.opponent
            { row := m.colourPiecePos.pos.row, col := midCol } = true := by
        simpa [Bool.and_eq_true, and_assoc] using hSafe'
      have hMidSafe :
          !isSquareAttacked s.board m.colourPiecePos.colourPiece.colour.opponent
            { row := m.colourPiecePos.pos.row, col := midCol } = true := hDecomp.2.2
      simpa [midExpr, hMid] using hMidSafe

theorem legal_implies_pseudoLegal
  (s : GameState) (m : Move)
  (h : isLegalMove s m = true) :
  isPseudoLegalMove s m = true := by
  unfold isLegalMove at h
  by_cases hp : isPseudoLegalMove s m
  · simp only [hp]
  · simp [hp] at h

theorem legal_implies_kingSafeAfter
  (s : GameState) (m : Move)
  (h : isLegalMove s m = true) :
  isInCheck (s.makeMove m) s.turn = false := by
  unfold isLegalMove at h
  by_cases hp : isPseudoLegalMove s m
  · have hAnd : (!isInCheck (s.makeMove m) s.turn &&
      (if isCastlingMove m then castlePathSafe s m else true)) = true := by
      simpa [hp] using h
    have hDecomp :
        !isInCheck (s.makeMove m) s.turn = true ∧
        (if isCastlingMove m then castlePathSafe s m else true) = true := by
      simpa [Bool.and_eq_true] using hAnd
    have hLeft : !isInCheck (s.makeMove m) s.turn = true := by
      exact hDecomp.1
    simpa using hLeft
  · simp [hp] at h

theorem legal_castling_implies_castlePathSafe
  (s : GameState) (m : Move)
  (hLegal : isLegalMove s m = true)
  (hCastle : isCastlingMove m = true) :
  castlePathSafe s m = true := by
  unfold isLegalMove at hLegal
  have hp : isPseudoLegalMove s m = true := legal_implies_pseudoLegal s m hLegal
  have hAnd : (!isInCheck (s.makeMove m) s.turn &&
      (if isCastlingMove m then castlePathSafe s m else true)) = true := by
    simpa [hp] using hLegal
  have hDecomp :
      !isInCheck (s.makeMove m) s.turn = true ∧
      (if isCastlingMove m then castlePathSafe s m else true) = true := by
    simpa [Bool.and_eq_true] using hAnd
  have hRight : (if isCastlingMove m then castlePathSafe s m else true) = true := by
    exact hDecomp.2
  simpa [hCastle] using hRight

theorem isCheckmate_implies_isInCheck
  (s : GameState) (c : Colour)
  (h : isCheckmate s c = true) :
  isInCheck s c = true := by
  unfold isCheckmate at h
  have hDecomp : isInCheck s c = true ∧ !hasAnyLegalMove s c = true := by
    simpa [Bool.and_eq_true] using h
  exact hDecomp.1

theorem isCheckmate_implies_noLegalMoves
  (s : GameState) (c : Colour)
  (h : isCheckmate s c = true) :
  hasAnyLegalMove s c = false := by
  unfold isCheckmate at h
  have hDecomp : isInCheck s c = true ∧ !hasAnyLegalMove s c = true := by
    simpa [Bool.and_eq_true] using h
  have hNoMoves : !hasAnyLegalMove s c = true := hDecomp.2
  simpa using hNoMoves

theorem isCheckmate_def
  (s : GameState) (c : Colour) :
  isCheckmate s c = (isInCheck s c && !hasAnyLegalMove s c) := by
  rfl

theorem isGameOver_ifEitherCheckmate
  (s : GameState)
  (h : isCheckmate s .white = true ∨ isCheckmate s .black = true) :
  isGameOver s = true := by
  unfold isGameOver
  cases h with
  | inl hw =>
      simp [hw]
  | inr hb =>
      simp [hb]

theorem castling_history_prepends_move
  (s : GameState) (m : Move)
  (_hCastle : isCastlingMove m = true)
  (hPseudo : isPseudoLegalMove s m = true) :
  (s.makeMove m).history = m :: s.history := by
  exact makeMove_history_of_pseudoLegal s m hPseudo

end Chess
