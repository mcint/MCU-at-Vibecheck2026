import sys
import json
import os
from pathlib import Path
from typing import List, Literal
from pydantic import BaseModel, Field
from openai import OpenAI
from dotenv import load_dotenv

load_dotenv(dotenv_path=Path(__file__).resolve().with_name(".env"), override=True)

openai_model = "gpt-5"

class ChessMove(BaseModel):
    """Represents a single chess move with piece, color, and positions."""
    piece: Literal["king", "queen", "rook", "bishop", "knight", "pawn"]
    color: Literal["white", "black"]
    initial_position: str = Field(description="The square the piece starts on (e.g., 'e1').")
    final_position: str = Field(description="The square the piece moves to (e.g., 'g1').")

class CheckmateSolution(BaseModel):
    """The sequence of moves leading to checkmate."""
    moves: List[ChessMove]

def solve_chess_puzzle(fen: str):
    if not os.getenv("OPENAI_API_KEY"):
        raise RuntimeError(
            "OPENAI_API_KEY not found. Set it in a .env file or export it in your shell."
        )
    client = OpenAI()

    instructions = (
        f"Analyze this chess board position given in FEN notation: {fen}\n"
        "Provide the sequence of forced moves for a checkmate. "
        "Strictly adhere to these formatting rules:\n"
        "1. DO NOT use algebraic notation (e.g., avoid 'Nf3', 'Qh5+').\n"
        "2. Provide every move as a 4-tuple: (piece name, color of piece, initial square, final square).\n"
        "3. A square on the board is a string of length 2, with an alphabet from 'a' to 'h' for file and a number from '1' to '8' for rank (e.g., 'e4')"
        "4. Identify the 'color' for every move ('white' or 'black').\n"
        "5. Output the moves in the correct sequential order."
        "6. Use ONLY these piece names: 'king', 'queen', 'rook', 'bishop', 'knight', 'pawn'.\n"
        "7. For CASTLING: Represent the move ONLY as the king moving two squares to the left or right (e.g., 'e1' to 'g1' for white kingside, or 'e8' to 'c8' for black queenside). Do not include a separate rook move.\n"
    )

    try:
        completion = client.beta.chat.completions.parse(
            model=openai_model,
            messages=[
                {
                    "role": "system",
                    "content": "You are a Grandmaster chess engine specializing in tactical checkmate puzzles. You output move sequences that lead to checkmate in a specific structured JSON format."
                },
                {"role": "user", "content": instructions},
            ],
            response_format=CheckmateSolution,
        )

        solution = completion.choices[0].message.parsed
        print(solution.model_dump_json(indent=2))

    except Exception as e:
        error_output = {"status": "error", "message": str(e)}
        print(json.dumps(error_output, indent=2))
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 script.py '<FEN_STRING>'")
        sys.exit(1)

    solve_chess_puzzle(sys.argv[1])
