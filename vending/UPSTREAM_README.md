# Verified LLM Chess: Mate-in-N Solver

## Origin
This project was built during the **LeanLang for Verified
Autonomy Hackathon** (April 17–18 + online through May 1, 2026) at the **Indian Institute of Science (IISc),
Bangalore**.
Sponsored by **[Emergence AI](https://www.emergence.ai)**
Organized by **[Emergence India Labs]
(https://east.emergence.ai)** in collaboration with
**IISc Bangalore**.

## Problem Objective
The goal of this project is to create a formally verified bridge between Large Language Models (LLMs) and a mathematical proof engine (Lean 4). Specifically, it targets **Chess Mate-in-N puzzles**, where an LLM suggests a sequence of moves to achieve checkmate, and Lean 4 rigorously verifies that:
1. Every move in the sequence is physically legal according to the rules of chess.
2. The final state is a mathematically sound checkmate.

## Setup
From the repo root:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip3 install pydantic openai
pip3 install python-dotenv
```

Set API key in a `.env` file at repo root:

```bash
echo 'OPENAI_API_KEY="sk-..."' > .env
```

Alternative: export directly in shell:

```bash
echo 'export OPENAI_API_KEY="sk-..."' >> ~/.zshrc
source ~/.zshrc
```

## Running the Tool
1. Build the Lean project:
```bash
lake build
```

2. Run the solver with a FEN string:
```bash
lake exe chess "<FEN>"
```
Example:
```bash
lake exe chess "1rb5/4r3/3p1npb/3kp1P1/1P3P1P/5nR1/2Q1BK2/bN4NR w - - 3 61"
```

3. (Optional) Debug the Python solver directly to see raw backend errors:
```bash
python3 script.py "<FEN>"
```

## Alternative: Run Without API Access
If current API keys are unavailable or quota-limited, use the following local mock setup to understand how the verification pipeline works end-to-end.

1. Create a local `python3` mock executable:
```bash
mkdir -p .mockbin
echo '#!/usr/bin/env bash' > .mockbin/python3
echo 'printf "%s\n" "{\"moves\":[{\"piece\":\"rook\",\"color\":\"white\",\"initial_position\":\"g3\",\"final_position\":\"g4\"}]}"' >> .mockbin/python3
chmod +x .mockbin/python3
```

2. Verify the mock output is valid JSON:
```bash
.mockbin/python3
```

3. Run the Lean executable with the mock in `PATH`:
```bash
PATH="$(pwd)/.mockbin:$PATH" lake exe chess "1rb5/4r3/3p1npb/3kp1P1/1P3P1P/5nR1/2Q1BK2/bN4NR w - - 3 61"
```

This mode does not call any LLM. It is intended only to demonstrate parsing, move validation, and final-state checking.

## Suggested Puzzles
You can find several Mate-in-N puzzles in FEN notation to test here:
*   [Mate in 2 Puzzles](https://wtharvey.com/m8n2.txt)
*   [Mate in 3 Puzzles](https://wtharvey.com/m8n3.txt)
*   [Mate in 4 Puzzles](https://wtharvey.com/m8n4.txt)

## Acknowledgments
This project was made possible by:
- **Emergence AI** — Hackathon sponsor
- **Emergence India Labs** — Event organizer and
research direction
- **Indian Institute of Science (IISc), Bangalore** —
Academic partner, hackathon co-design, tutorials,
and mentorship

## Links
- [Hackathon Page](https://east.emergence.ai/hackathon-april2026.html)
- [Emergence India Labs](https://east.emergence.ai)
- [Emergence AI](https://www.emergence.ai)
