# Rulebreakers: can you beat the vending machine?

A customer pays for a drink, requests a refund while the motor is running, and walks away with **both the drink and the returned coin**. Each button seems reasonable; their interaction breaks the business promise.

This demo lets a person or an optional Claude attacker try the same actions against old and repaired rules. Lean executes the moves, produces the displayed outcomes, and separately checks proofs about the repaired model.

For the separate tax-policy demo, see [Policy Lab](../tax-game/README.md).

For private Linux hosting and persistent services, see the shared [deployment guide](../../DEPLOYMENT.md).

## Quick start

From the repository root:

```sh
cd projects/workflow-game
python3 demo.py --port 8766
```

Open the **single-customer demo**: <http://127.0.0.1:8766/?scenario=solo>.

Requirements: Python 3.10+, `elan`/`lake`, and Lean **4.35.0**, pinned in [lean-toolchain](lean-toolchain). The launcher builds the Lean executable before serving the page. First use may download the pinned toolchain. Manual play and tests require no API key, Mathlib, or third-party Python packages.

| Round | URL | What it demonstrates |
| --- | --- | --- |
| Refund race — recommended first | `http://127.0.0.1:8766/?scenario=solo` | One customer exploits a refund during delivery. |
| Rush hour — experimental extension | `http://127.0.0.1:8766/?scenario=rush` | Two orders interact through stock reservations and refund retries. |

The bare `/` URL opens the single-customer Refund race; add `?scenario=rush` for Rush hour. `?embed=1` hides the page chrome for iframes; `?autoplay=1` starts the recorded attack immediately. The page also opens directly from `web/index.html` over `file://` with no server: it then replays the recorded Claude run (with the Lean transitions captured from the engine for that exact run) and disables free play. See [DEMO-NOTES.md](DEMO-NOTES.md) for the presenter script.

## The 60-second single-customer walkthrough

1. State the promise: **a drink or a returned coin; never both**.
2. Press **Watch AI attack** when a recorded run is available, or **Play challenge** on a fresh checkout. Both cabinets replay through the live Lean interpreter.
3. Under the old rule, REFUND returns the coin immediately while the motor keeps running. The drink can still drop. Both possession icons light up.
4. Under the repair, REFUND waits for the motor. Delivery keeps payment; a jam returns the coin.
5. Point to **Attack log × Lean**: each actual accepted/rejected move has its formal transition beside it. Open **Rules & proof** for the English rules, Lean propositions, and theorem names.

For manual play, use **+ COIN → BUY → REFUND**, then **Drink drops**. Machine responses are automatic. The motor/coin buttons simulate the explicit external outcomes in this model. Stop cancels replay; reset starts over. Selecting another recorded plan retains unsuccessful attempts as well as successful ones.

![Single-customer game and live Lean log](../../tickets/in-progress/business-workflow-games/evidence/game-desktop.png)

## What is checked, searched, and proved?

These are different evidence levels:

| Evidence | Meaning | Main source |
| --- | --- | --- |
| Native replay | Every submitted action is parsed and executed against the model. Invalid histories are rejected. | [Model.lean](VendingGame/Model.lean), [VendingGameMain.lean](VendingGameMain.lean) |
| Concrete failing witness | An allowed old-policy execution gives the customer both items. | `broken_policy_violates_promise` in [Policy.lean](VendingGame/Policy.lean) |
| Repaired policy invariant | Every state reachable under the specific repaired machine rule avoids that outcome. | `repaired_policy_never_gives_both` |
| API-to-proof bridge | Every accepted repaired-policy replay ends in a state covered by the invariant. | `accepted_repaired_history_safe` |
| Strategy result | The generic game checker is connected to an inductive strategy definition; the repaired machine has a strategy and the broken machine cannot force safe completion. | [Verify.lean](VendingGame/Verify.lean) |

The displayed business promise is linked to the ownership fields by:

```lean
Safe s ↔ ¬ (s.coinWithPlayer = true ∧ s.drinkWithPlayer = true)
```

The invariant is proved by induction over permitted executions, without a history-length bound. The guided solo counterexample comes from `findFailure` with an eight-step search bound. That search bound is separate from the invariant. Runtime execution in the browser is also separate from kernel-checking theorem declarations at build time.

The new business-game proofs use standard Lean axioms `propext` and, for some declarations, `Quot.sound`. They contain no `sorry`, custom axioms, or `native_decide`. No SMT service is used. A failed Claude attempt is not a safety proof.

## Run the checks or replay a trace

```sh
# Builds both business-game executables and runs 52 acceptance checks.
python3 demo.py --check

# Old machine: the customer receives both items.
lake exe vending_game play-policy 3 insertCoin,buy,askRefund,returnCoin,motorDelivers

# Repaired machine: successful delivery keeps payment.
lake exe vending_game play-policy 4 insertCoin,buy,askRefund,waitForMotor,motorDelivers

# Repaired machine: a jam returns the coin.
lake exe vending_game play-policy 4 insertCoin,buy,askRefund,waitForMotor,motorJams,returnCoin,coinReturned
```

Levels 1 and 2 retain the introductory purchase/refund examples. Levels 3 and 4 are the old and repaired policies. Use `play-policy` for the same enforced policy as the HTTP API. Raw CLI `play` deliberately permits alternative machine choices, including choices excluded by the repaired policy.

The 52 checks include the earlier order-model baseline, solo vending, Rush hour, HTTP validation, and mocked-provider tests. They make no paid model calls. Build output prints the main theorem axiom dependencies.

## Optional: let Claude propose attacks

Set `ANTHROPIC_API_KEY` or `ANTHROPIC_KEY` on the server, or in the existing repository/workspace `.env`. Optional `ANTHROPIC_MODEL` selects a model; otherwise the adapter discovers an available model, preferring Haiku. Keys are never sent to the browser.

```sh
# One explicit live generation, followed by old/repaired replay.
python3 demo.py --ai-check 3 --scenario solo

# The experimental round has its own rules and cache.
python3 demo.py --ai-check 3 --scenario rush
```

Each generation is capped at 1,400 output tokens, three plans, and twelve actions per plan. The server allows three generations per round per process. Claude receives public rules and allowed customer/scheduler actions, without known counterexamples or winning-region hints. It cannot edit rules or choose the machine response. Later rounds may use earlier observed results as feedback.

Saved runs are labeled **recorded**, and provider failures remain explicit. Runtime caches in `runs/` are ignored by Git, so a fresh checkout starts with checked examples until you generate a recording. Historical synthetic game reports and screenshots are preserved in the [research/validation ticket](../../tickets/in-progress/business-workflow-games/).

## Experimental Rush-hour round

This retained extension adds two one-coin orders, one delivery slot, mid-delivery refunds, and repeated refund requests. The three old-rule failures are double booking, a drink after a refund, and a duplicate refund payout. The repair reserves capacity, waits for delivery, and acknowledges completed refund retries without another payout.

[RushGame/Verify.lean](RushGame/Verify.lean) proves the three promises together. An auxiliary `Protected` invariant excludes an already-refunded running motor, which looks safe until its next delivery. The compiled repaired graph has 27 reachable states and 72 enabled transitions out of 81 representable phase combinations.

Claims represent delivery commitments, not extra physical cans. Refund payouts use a modeled cash float and abstract two or more payouts as 2. The native HTTP history limit is 32 actions; the repaired induction theorem has no such limit.

## Model boundaries

The solo round has one coin, one drink, one transaction, explicit turns, and the listed motor/coin outcomes. It excludes actual hardware, arbitrary network messages, hidden state, indefinite delays, and duplicate events. Rush hour adds only the specific interactions above. These are proofs about those models, not production vending/payment software or completeness of real-world business requirements. Editable natural-language/CNL rule authoring is not implemented.

## Source map and provenance

- [VendingGame/Walkthrough.lean](VendingGame/Walkthrough.lean): first read for a Lean audience.
- [VendingGame/BusinessRules.lean](VendingGame/BusinessRules.lean): rule-to-proposition mappings.
- [demo.py](demo.py), [adversary.py](adversary.py), [web/index.html](web/index.html): local server, untrusted proposer, and interface.
- [OrderGame/](OrderGame/): earlier order/payment example, available through `lake exe order_game`.
- [NOTICE.md](NOTICE.md), [LICENSE](LICENSE), [UPSTREAM_README.md](UPSTREAM_README.md): MARS provenance and preserved MIT attribution.

The project derives from [MARS / Verified LLM Chess](https://github.com/EmergenceAI/Lean-Hackathon-aastha-guptaa/tree/2df34bb66cfea5f2653039bd3334ce3fa908e54c). Original chess sources remain an explicit `lake build chess` target; their correctness is outside the new business-game claims.

If loading fails, confirm the launcher is running, use the printed loopback port, and reconnect. If the native engine is unavailable, run `lake build` or restart `python3 demo.py`. Stop this task-owned server with Ctrl+C.
