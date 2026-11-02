import Chess.Model

def Piece.toIcon (piece: Piece) (colour: Colour) : String :=
  match piece, colour with
  | .king,   .white => "♚"
  | .queen,  .white => "♛"
  | .rook,   .white => "♜"
  | .bishop, .white => "♝"
  | .knight, .white => "♞"
  | .pawn,   .white => "♟"
  | .king,   .black => "♔"
  | .queen,  .black => "♕"
  | .rook,   .black => "♖"
  | .bishop, .black => "♗"
  | .knight, .black => "♘"
  | .pawn,   .black => "♙"

def Square.toIcon (square: Square) : String :=
  match square with
  | none => "□"
  | some cp => cp.piece.toIcon cp.colour

instance : Repr Square where
  reprPrec square _ := square.toIcon

def vecToString {n : Nat} (v : Vector Square n) : String :=
  v.foldl (fun s sq => s ++ sq.toIcon) ""

instance : ToString Colour where
  toString col :=
    match col with
    | .white => "white"
    | .black => "black"

instance : Repr Board where
  reprPrec board _ :=
    board.foldl (fun s row => s ++ vecToString row ++ "\n") ""

instance : ToString Board where
  toString board :=
    board.foldl (fun s row => s ++ vecToString row ++ "\n") ""

instance : Repr GameState where
  reprPrec gs _ :=
    let valid := s!"Valid: {gs.valid}\n"
    let turn := s!"Turn: {gs.turn}\n"
    let moveNum := s!"Move Number: {gs.moveNum}\n"
    let board := s!"{gs.board}"
    valid ++ turn ++ moveNum ++ board

instance : ToString GameState where
  toString gs :=
    let valid := s!"Valid: {gs.valid}\n"
    let turn := s!"Turn: {gs.turn}\n"
    let moveNum := s!"Move Number: {gs.moveNum}\n"
    let board := s!"{gs.board}"
    valid ++ turn ++ moveNum ++ board

instance : Repr <| List GameState where
  reprPrec lgs n :=
    lgs.foldl (fun s gs => s ++ "\n" ++ reprPrec gs n) ""

instance : ToString <| List GameState where
  toString lgs :=
    lgs.foldl (fun s gs => s ++ toString gs ++ "\n") ""
