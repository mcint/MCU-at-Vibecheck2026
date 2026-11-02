import Lean.Data.Json
import Lean.Data.Json.FromToJson
import Chess.Model
import Chess.Display

open Lean

def stringToColour (s : String) : Option Colour :=
  match s.toLower with
  | "white" => some .white
  | "black" => some .black
  | _ => none

def charToFin (c : Char) : Option (Fin 8) :=
  match c with
  | 'a' => some 0 | 'b' => some 1 | 'c' => some 2 | 'd' => some 3
  | 'e' => some 4 | 'f' => some 5 | 'g' => some 6 | 'h' => some 7
  | '1' => some 7 | '2' => some 6 | '3' => some 5 | '4' => some 4
  | '5' => some 3 | '6' => some 2 | '7' => some 1 | '8' => some 0
  | _ => none

def stringToPos (s : String) : Option Pos :=
  match s.toList with
  | colChar :: rowChar :: [] =>
    match charToFin colChar, charToFin rowChar with
    | some c, some r => some ⟨r, c⟩
    | _, _ => none
  | _ => none

def stringToPiece (s : String) : Option Piece :=
  match s.toLower with
  | "pawn"   => some .pawn   | "rook"   => some .rook
  | "knight" => some .knight | "bishop" => some .bishop
  | "queen"  => some .queen  | "king"   => some .king
  | _        => none

structure JsonMove where
  piece : String
  color : String
  initial_position : String
  final_position : String
deriving FromJson, ToJson

structure JsonCheckmateSolution where
  moves : List JsonMove
deriving FromJson, ToJson

def convertMoves (jsonMoves : List JsonMove) : List Move :=
  match jsonMoves with
  | [] => []
  | jm :: rest =>
    let optMove : Option Move := do
      let p ← stringToPiece jm.piece
      let c ← stringToColour jm.color
      let start ← stringToPos jm.initial_position
      let target ← stringToPos jm.final_position
      return {
        colourPiecePos := { colourPiece := ⟨p, c⟩, pos := start },
        toPos := target,
        promotion := none
      }
    match optMove with
    | some m => m :: convertMoves rest
    | none   => convertMoves rest -- Skip invalid move entries

def parsePythonOutputToMoves (jsonInput : String) : Except String (List Move) := do
  let json ← Json.parse jsonInput
  let solution : JsonCheckmateSolution ← fromJson? json
  return convertMoves solution.moves
