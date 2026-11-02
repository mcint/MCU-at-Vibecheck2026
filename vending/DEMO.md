# The 90-second presenter script (solo round)

Start at `http://127.0.0.1:8766/` (defaults to the solo Refund race). The quick-read panel at the top can be skipped; `?` brings it back.

| t | Say | Do |
| --- | --- | --- |
| 0:00 | "House rule: a drink **or** your coin back — never both. Two machines, same buttons, different refund rule." | Point at the two cabinets and the HOUSE RULE line. |
| 0:10 | "Claude Haiku got only these public rules and was told to leave with both. Every move it proposes is executed by a compiled Lean program — the machine's replies too." | Press **▶ Watch AI attack** (recorded run, replays offline). |
| 0:25 | "Left: old rule. REFUND while the motor runs → coin comes back immediately → the drink still drops. Both icons light up. Claude wins." | Point at the left cabinet's two lit possession icons, badge **AI WINS**. |
| 0:40 | "Right: repaired rule. Same moves. Lean's policy makes the machine *wait for the motor*; the extra `coinReturned` Claude asked for is **rejected** — see the red REJECTED entry and the `policyStep … = none` line." | Point at the right-hand log and the accepted/rejected tally. |
| 0:55 | "This card is the literal theorem: `accepted_repaired_history_safe` — for every move list the server accepts under the repaired rule, the customer never holds coin and drink. Induction over every history, no length bound. `#print axioms`: `propext` only. No sorry." | Point at the verdict card / proof pin. |
| 1:15 | "Boundary: it's an 11-state model we wrote, with the bug and the fix both hand-encoded. The claim is 'Lean adjudicates an untrusted attacker against this model', not 'real vending machines are safe'." | Optionally open **Rules & proof** for the rule ↔ Lean table. |
| 1:25 | "Try it yourself." | Hand over: +COIN / BUY / REFUND / Drink drops; ← → to step. If a key is configured, run exactly **one** live round via *Challenge the repaired rules*. |

# Rush hour: the harder round

Switch to **Rush hour**. Two customers want the last drink. Both machines follow the same public commands, but their rules differ. Ask Claude for attack plans, then replay each plan against both machines. The game tracks each buyer and the number of committed delivery slots.

Try three combinations: both buyers BUY before either motor finishes; request a refund while a delivery runs; retry a completed refund. Old rules overbook, give away a drink, or pay twice. The repair reserves stock, waits for delivery, and ignores duplicate refunds. If a motor jams, the released slot remains available to the other buyer. The right-hand log explains each move in Lean; the invariant proves all three promises together over every accepted repaired history.

The delivery-slot counter represents reservations, so detecting an overbooking does not assert that two actual cans emerged from one. Refund quantities are a modeled ledger with machine cash float. The original one-customer round remains selectable.

# Rulebreakers: the 60-second demo

Start with the two cabinets, not the proof table. Point to the house rule: **a drink or a returned coin, never both**. The old machine refunds immediately while the motor runs; the repaired machine waits for the motor's result.

Press **Watch AI attack**. The labeled recorded Claude attempt replays through the live Lean interpreter on both machines. Watch the coin return on the left before the drink drops. Both possession icons light up. On the right, delivery keeps payment. Select another saved attempt to include failures, or explicitly request a new live round against either policy.

The physical coin, BUY, and REFUND buttons also work. Machine responses happen automatically; **Drink drops** and **Motor jams** simulate the modeled external outcomes. Reset starts fresh; stop lets the presenter take over.

Open **Rules & proof** only when asked how it works. It contains the actual public rule bundle supplied to Claude, every business rule beside its Lean representation, and the invariant proof. Open the attack log to inspect accepted and rejected moves. The empirical attack score is separate from Lean's proof over all permitted repaired-policy histories.

The older level progression remains available through the CLI:

**Can you get a drink and your coin back?**

Run `python3 demo.py` and open http://127.0.0.1:8766.

1. Buy normally: level 1, insert coin, BUY, drink drops. The drink is yours; the coin stays in the machine.
2. Change your mind: level 2, insert coin, REFUND, let machine respond, coin drops. The coin is yours; the drink stays in the machine.
3. Cheat: level 3, insert coin, BUY, REFUND before the drink drops, let machine return the coin, then choose **The drink drops**. Both objects are yours. The rule failed.
4. Repair: level 4, try the same trick. The machine holds the refund. If the drink drops, it keeps payment. If the motor jams, it returns the coin. Either branch is fair.

For a Lean audience, open `VendingGame/Walkthrough.lean`: first show the ownership predicate, then the five-action exploit, then the two repaired traces, then `repaired_has_strategy`. The checker in `Verify.lean` explains why every listed reply is covered.

A successful purchase in level 3 is only one execution. The no-strategy theorem shows the broken rules cannot handle every allowed case. Level 4 has a strategy; its safe response is selected by **Let the machine respond**.

This is a finite toy, not a proof about actual vending hardware. Every external outcome is one of the listed moves.


## AI adversary version

Show the AI panel first. Claude receives business rules, a player/scheduler action vocabulary, and the goal of obtaining both items. Run the old-policy attack or show the labeled recorded live result. Open its checked-move transcript: Claude proposes REFUND during dispensing; the machine returns the coin; the scheduled drink drop succeeds. Replay the identical plan under the repaired rule and show the different machine response.

The recorded test produced three plans: one succeeded under the old policy; none succeeded against the repaired policy. Preserve the failed plans as well. Then distinguish the empirical result from the induction proof, which covers all admitted repaired-policy histories.

The live log stays visible on the right of the game. As each move executes, point to its exact Lean `policyStep` expression and the returned state. The theorem above the log is a separate, build-checked invariant; the live expressions are evaluations through the compiled interpreter. On mobile, the log follows the machines.
