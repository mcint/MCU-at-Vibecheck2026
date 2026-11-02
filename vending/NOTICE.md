# Provenance

This directory is a derivative of [MARS / Verified LLM Chess](https://github.com/EmergenceAI/Lean-Hackathon-aastha-guptaa), revision `2df34bb66cfea5f2653039bd3334ce3fa908e54c`.

Original `Chess/`, `Chess.lean`, `Main.lean`, `script.py`, and `LICENSE` are preserved. Original documentation is `UPSTREAM_README.md`. The upstream MIT license and attribution remain in `LICENSE`.

Changes: pinned the derivative to Lean 4.35.0, added independent `OrderGame`, `VendingGame`, and `RushGame` models/proofs/executables, a local web interface and acceptance tests, and made `vending_game` the frontend backend and built both business examples by default. The original `chess` executable remains an explicit target.

The business example uses the proposer/checker architecture as a starting point. It does not import the original chess definitions into its proofs. Known chess-model issues documented in the research ticket have not been repaired here. No endorsement or new contribution by the upstream authors is implied.

Commit preparation normalized trailing whitespace in the preserved upstream `script.py`; its behavior and MIT attribution are unchanged.
