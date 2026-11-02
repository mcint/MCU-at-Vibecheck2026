# Rulebreakers — demo notes

Single page: `web/index.html` (vanilla HTML/CSS/JS, no CDN, ~70 KB because it embeds the
recorded Claude run, its Lean-evaluated node sequence, and the literal theorem texts).

## How to run

**Full demo (live Lean adjudication, free play, Rush hour):**

```sh
cd projects/workflow-game
python3 demo.py --port 8766        # builds with lake first; prints "Play the rules: http://127.0.0.1:8766"
```

Open <http://127.0.0.1:8766/> — bare `/` is the solo **Refund race**. Other URLs:

| URL | Purpose |
| --- | --- |
| `http://127.0.0.1:8766/?embed=1` | iframe mode (page chrome hidden; "open standalone ↗" top-right) |
| `http://127.0.0.1:8766/?autoplay=1` | starts the recorded attack on load |
| `http://127.0.0.1:8766/?scenario=rush` | the two-buyer extension (needs the server) |

The server is loopback-only and must be **port 8766** if the root `demos/index.html` iframe points
at it (per `DEPLOYMENT.md`). Requirements: Python ≥ 3.10, `elan`/`lake`, Lean 4.35.0 (pinned in
`lean-toolchain`). No API key, Mathlib, or pip packages are needed.

**No server (file:// or a plain static host):** open `web/index.html` directly. The page detects
that `/api/play` is unreachable and switches to **offline mode**: "▶ Watch AI attack", the three
recorded attempts, ← → stepping, the attack log with `policyStep … = some/none` lines, the tally,
the verdict card and the theorem pin all work. Free play is limited to moves that lie on the
recorded paths; Rush hour shows an error asking for the server. The Lean transitions shown offline
were captured by running `lake exe vending_game play-policy <3|4> <prefix>` for every prefix of the
recorded run (the embedded `NODES` table is the engine's per-node output, not a JS re-implementation).

**Recorded run:** `runs/ai-latest.json` is the real `claude-haiku-5-5` session (3 plans; old rule:
1 exploit, repaired: 0). `runs/` is gitignored — on a fresh checkout the page still shows the same run
because it is embedded in the HTML; the server-side copy only matters for `/api/ai`.

**Checks:** `lake build` (35 jobs, prints `#print axioms` for every headline theorem) and
`python3 demo.py --check` → 52 tests OK (verified today). `python3 demo.py --help` works without
building.

**Live Claude round (optional, never required):** set `ANTHROPIC_API_KEY` server-side; the buttons
"New live attack · old rules" / "Challenge the repaired rules" enable themselves (3 generations per
process). Without a key or network they stay disabled and the recorded run is used. A failed live
call shows a toast and leaves the recorded attempts available.

## Controls

- **▶ Watch AI attack** — replays the selected Claude attempt on both machines (auto, 0.85 s/move).
- **‹ prev / next ›** or keyboard **← →** — step one move at a time; prev re-replays the prefix
  through Lean. **Space** toggles play/pause. **Ⅱ** stops; **↺** resets.
- Cabinet buttons **+ COIN / BUY / REFUND** and the outcome chips **Drink drops / Motor jams /
  Coin returns** — free play; Lean rejects anything the policy disallows (red REJECTED entry).
- **CLAUDE'S ATTEMPTS** picker — the three recorded plans, including the two that failed.
- **Rules & proof** drawer — the exact rule bundle Claude received, the rule ↔ Lean table, and
  three canned traces. **Attack log & experiment details** — full paired transcripts.
- Quick-read panel: **skip ✕** hides it (remembered in `localStorage`), **?** brings it back.

## 90-second presenter script

See the table in `DEMO.md` ("The 90-second presenter script"). Condensed:

1. (0:00) House rule: *a drink or your coin back — never both.* Two machines, same buttons, different refund rule.
2. (0:10) Claude Haiku got only the public rules and the goal "leave with both". Press **▶ Watch AI attack**. Every move — Claude's, the motor's and the machine's reply — runs through the compiled Lean engine.
3. (0:25) Left cabinet: REFUND mid-motor → coin back immediately → drink still drops → both icons lit, **AI WINS**.
4. (0:40) Right cabinet, same moves: the policy makes the machine wait; Claude's extra `coinReturned` is **REJECTED** (`policyStep .repaired .served .coinReturned = none`). Point at the tally.
5. (0:55) Verdict card = literal theorem `accepted_repaired_history_safe` + `#print axioms … [propext]`. Induction over *every* accepted history, no length bound, no sorry, no native_decide.
6. (1:15) Boundary sentence (below). Hand over the buttons.

## What is NOT proven

- **Model-relative only.** The theorems are about an 11-state automaton (`VendingGame/Model.lean`)
  whose bug *and* repair were both hand-written by us. Nothing is claimed about real vending
  hardware, payment systems, network messages, duplicate events, indefinite delays or hidden state.
- **A failed Claude attack is not a safety proof**, and the recorded run (3 plans) is an experiment,
  not evidence of anything beyond "Lean adjudicated these plans". Safety comes from the theorem only.
- **The proof is a finite model check in induction clothing**: preservation lemmas are
  `cases … <;> simp_all <;> decide` over all states × actions. Rush hour (81 states) already needs
  `maxHeartbeats 4000000`; it would not scale to judge-proposed rule changes live.
- **Rush hour's counters are abstractions**: "claims" are delivery commitments, not physical cans;
  refund payouts cap at 2; the HTTP history limit is 32 actions (the theorem has no such limit).
- **Browser execution ≠ kernel checking.** The live log shows evaluations by the compiled binary;
  the theorem was checked once at `lake build`. The bridge is `accepted_repaired_history_safe`,
  stated over the same `policyReplay` the server runs — the TCB is the Lean compiler/runtime.
- No rule-authoring layer: every scenario is hand-modelled Lean. The upstream chess code (MARS
  scaffold) is built only as an explicit target and is not part of any claim.
