import Chess

def main (args : List String) : IO Unit := do
  match args with
  | [] => return ()
  | fen :: _ =>
    let state := fenToGameState fen
    let res ← IO.Process.run { cmd := "python3", args := #["script.py", fen] }
    IO.println s!"Output from LLM: {res}"
    IO.println "================================="
    match parsePythonOutputToMoves res with
    | .error s =>
      IO.println "Error parsing Json output from LLM to List Move!"
      throw <| IO.userError s!"{s}"
    | .ok moves =>
      if state.isValidMoves moves then
        let final_state := state.playMoves moves
        if final_state.isAnyCheckmate then
          IO.println "Puzzle Successfully Solved!"
          let states_seq := state.getStatesSequence moves
          IO.println "The board positions to checkmate:\n"
          IO.println s!"{states_seq}"
        else
          IO.println "Moves do not end in Checkmate!"
      else
        IO.println "Moves are invalid!"
