"""A bounded, untrusted Claude attacker; Lean alone adjudicates its moves."""
from __future__ import annotations

from datetime import datetime, timezone
import json
import os
from pathlib import Path
import threading
from typing import Callable
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parent
API = "https://api.anthropic.com/v1"


def settings() -> dict[str, str]:
    names = {"ANTHROPIC_API_KEY", "ANTHROPIC_KEY", "ANTHROPIC_MODEL"}
    values = {name: os.environ[name] for name in names if os.environ.get(name)}
    for path in (ROOT.parents[1] / ".env", ROOT.parents[2] / ".env"):
        if not path.is_file():
            continue
        for line in path.read_text().splitlines():
            name, separator, value = line.strip().removeprefix("export ").partition("=")
            if separator and name.strip() in names:
                value = value.strip()
                if len(value) > 1 and value[0] == value[-1] and value[0] in "\"'":
                    value = value[1:-1]
                values.setdefault(name.strip(), value)
    return values


def public_rules(level: str, scenario: str = "solo") -> dict:
    if scenario == "rush":
        operations = {"insertCoin": "Insert this buyer's coin", "buy": "Press BUY for this buyer",
                      "askRefund": "Request this buyer's refund", "motorDelivers": "Schedule this buyer's motor delivering",
                      "motorJams": "Schedule this buyer's motor jamming", "retryRefund": "Repeat a completed refund request"}
        return {
            "policy": "Old rush-hour rules" if level == "3" else "Repaired rush-hour rules",
            "goal": "Violate any promise: at most one delivery claim; no buyer gets a drink and refund; at most one refund payout per buyer.",
            "rules": [
                "Buyers A and B each start with one coin. There is one drink and one delivery slot.",
                "Each buyer has one order. Insert a coin before BUY. A buyer without accepted credit cannot buy.",
                "BUY claims a delivery slot and starts that buyer's motor. A pending or delivered order consumes the slot.",
                ("Old BUY checks whether a drink was delivered, but does not check another pending delivery claim."
                 if level == "3" else "Repaired BUY atomically requires no other pending or fulfilled delivery claim."),
                "REFUND before BUY returns the coin. A motor jam returns the coin and releases that buyer's slot.",
                ("Old REFUND during a running delivery pays immediately while the motor continues."
                 if level == "3" else "Repaired REFUND during delivery waits for the motor. Delivery keeps payment; a jam refunds."),
                ("Old retryRefund repeats the payout on a completed refund."
                 if level == "3" else "Repaired retryRefund acknowledges a completed refund without another payout."),
                "Motor events address the named buyer and require that buyer's running motor. A delivered order cannot start again.",
                "You can interleave both buyers' actions and select listed motor outcomes as a test scheduler. Machine decisions are automatic.",
                "The delivery counter counts commitments, not physical cans. Refunds use a modeled cash float; two or more payouts are recorded as 2.",
            ],
            "player_actions": {operation + buyer: description + " (" + buyer + ")"
                               for buyer in ("A", "B") for operation, description in operations.items()},
        }
    if scenario != "solo":
        raise ValueError("Choose solo or rush.")
    return {
        "policy": "Old refund policy" if level == "3" else "Repaired refund policy",
        "goal": "Finish with both the drink AND the original coin. Try to exploit the rules.",
        "rules": [
            "A transaction starts with one coin in your hand and one drink in the machine.",
            "Insert your coin before pressing BUY. BUY starts the dispenser motor.",
            "Before BUY, REFUND returns the coin and ends the transaction without a drink.",
            "While the motor runs, a refund can be requested; the motor may deliver or jam.",
            ("The old machine immediately returns the coin on that request. The motor continues."
             if level == "3" else
             "The repaired machine holds the refund until the motor finishes. Delivery keeps payment; a jam returns the coin."),
            "The machine responds automatically. You cannot choose or change its response.",
            "You may select listed dispenser outcomes as an adversarial test scheduler. You do not control real hardware.",
            "A completed transaction accepts no more actions. No new transactions or arbitrary state edits are available.",
        ],
        "player_actions": {
            "insertCoin": "Insert the coin", "buy": "Press BUY", "askRefund": "Press REFUND",
            "motorDelivers": "Schedule the drink dropping", "motorJams": "Schedule a jam",
            "coinReturned": "Confirm that the refund coin drops into the tray",
        },
    }


def validate_attacks(data: dict) -> list[dict]:
    if not isinstance(data, dict) or set(data) != {"attacks"}:
        raise ValueError("The model did not return the required attack-plan object.")
    plans = data["attacks"]
    if not isinstance(plans, list) or not 1 <= len(plans) <= 3:
        raise ValueError("The model must propose one to three attacks.")
    for plan in plans:
        if not isinstance(plan, dict) or set(plan) != {"title", "tactic", "moves"}:
            raise ValueError("An attack plan has an invalid shape.")
        for key, limit in (("title", 90), ("tactic", 300)):
            if not isinstance(plan[key], str) or not 1 <= len(plan[key]) <= limit:
                raise ValueError("The model returned an oversized or invalid explanation.")
        if not isinstance(plan["moves"], list) or not 1 <= len(plan["moves"]) <= 12:
            raise ValueError("An attack must contain one to twelve proposed actions.")
        if any(not isinstance(move, str) or not 1 <= len(move) <= 48 for move in plan["moves"]):
            raise ValueError("An attack contains an invalid action value.")
        if any("," in move for move in plan["moves"]):
            raise ValueError("Each proposed action must be one action, not a serialized history.")
    return plans


ATTACK_SCHEMA = {
    "type": "object", "additionalProperties": False, "required": ["attacks"],
    "properties": {"attacks": {"type": "array", "minItems": 1, "maxItems": 3,
        "items": {"type": "object", "additionalProperties": False,
            "required": ["title", "tactic", "moves"], "properties": {
                "title": {"type": "string", "maxLength": 90},
                "tactic": {"type": "string", "maxLength": 300},
                "moves": {"type": "array", "minItems": 1, "maxItems": 12,
                          "items": {"type": "string", "maxLength": 48}},
            }}}},
}


class ClaudeAttacker:
    def request(self, path: str, body: dict | None = None) -> dict:
        config = settings()
        key = config.get("ANTHROPIC_API_KEY") or config.get("ANTHROPIC_KEY")
        if not key:
            raise RuntimeError("No Anthropic key is configured on the server. The manual demo still works.")
        request = Request(API + path, data=None if body is None else json.dumps(body).encode(), headers={
            "x-api-key": key, "anthropic-version": "2023-06-01", "content-type": "application/json",
        })
        try:
            with urlopen(request, timeout=45) as response:
                return json.load(response)
        except HTTPError as error:
            status = error.code
            error.close()
            raise RuntimeError(f"Anthropic returned HTTP {status}; no simulated LLM result was substituted.") from None
        except (URLError, TimeoutError):
            raise RuntimeError("The Anthropic service could not be reached. No simulated result was substituted.") from None

    def propose(self, level: str, feedback: list[dict], scenario: str = "solo") -> tuple[str, list[dict]]:
        model = settings().get("ANTHROPIC_MODEL")
        if not model:
            available = [row["id"] for row in self.request("/models?limit=100").get("data", [])]
            model = next((m for m in available if "haiku" in m), None)
            model = model or next((m for m in available if "sonnet" in m), None)
            model = model or next(iter(available), None)
            if not model:
                raise RuntimeError("No available Claude model was returned by the provider.")
        prompt = public_rules(level, scenario)
        if feedback:
            prompt["previous_observed_results"] = feedback
        response = self.request("/messages", {
            "model": model, "max_tokens": 1400,
            "system": "You are an adversarial customer testing a toy vending machine. "
                      "Propose up to three different short action sequences that violate a stated business promise. "
                      "Use the public business rules. You may try invalid ordering or repeated buttons, "
                      "but cannot edit rules or select machine actions. The machine responds between your moves. "
                      "Give a brief public tactic description, not hidden reasoning. "
                      "Never claim success: an independent engine executes and judges every attempt.",
            "messages": [{"role": "user", "content": json.dumps(prompt)}],
            "tools": [{"name": "submit_attacks", "description": "Submit bounded attack plans for execution.",
                       "input_schema": ATTACK_SCHEMA}],
            "tool_choice": {"type": "tool", "name": "submit_attacks"},
        })
        blocks = [block for block in response.get("content", [])
                  if block.get("type") == "tool_use" and block.get("name") == "submit_attacks"]
        if len(blocks) != 1:
            raise RuntimeError("The model did not supply one structured attack response.")
        return response.get("model", model), validate_attacks(blocks[0].get("input"))


def evaluate_attack(engine: Callable[[str, str], dict], level: str, plan: dict) -> dict:
    moves: list[str] = []
    game = engine(level, "")
    events: list[dict] = []

    def attempt(action: str, actor: str) -> bool:
        nonlocal game
        label = next((a["label"] for a in game["actions"] if a["id"] == action), action)
        try:
            after = engine(level, ",".join(moves + [action]))
        except ValueError as error:
            events.append({"actor": actor, "action": action, "label": label,
                           "accepted": False, "result": str(error)})
            return False
        moves.append(action)
        game = after
        events.append({"actor": actor, "action": action, "label": label,
                       "accepted": True, "result": game["state"],
                       "coin": game["coinWithPlayer"], "drink": game["drinkWithPlayer"]})
        return True

    for proposed in plan["moves"]:
        if not attempt(proposed, "LLM"):
            break
        for _ in range(3):
            if game["actor"] != "Machine" or not game["actions"]:
                break
            if not attempt(game["machineChoice"], "Machine rule"):
                raise RuntimeError("The engine rejected its own machine-policy action.")
        if not game["safe"]:
            break
    return {"level": int(level), "events": events, "moves": moves,
            "state": game["state"], "exploitFound": not game["safe"],
            "coin": game["coinWithPlayer"], "drink": game["drinkWithPlayer"],
            "settled": game["settled"], "policyTheorem": game["policyTheorem"],
            "violations": game.get("violations", []), "buyers": game.get("buyers", []),
            "claims": game.get("claims")}


class Experiment:
    def __init__(self, cache_path: Path | None = None, *, scenario: str = "solo"):
        if scenario not in {"solo", "rush"}:
            raise ValueError("Choose solo or rush.")
        self.scenario = scenario
        self.lock = threading.Lock()
        self.calls = 0
        self.cache_path = cache_path
        self.latest = None
        if cache_path and cache_path.is_file():
            try:
                report = json.loads(cache_path.read_text())
                if (isinstance(report, dict) and report.get("source") == "Anthropic API"
                        and report.get("scenario", "solo") == scenario):
                    self.latest = report
            except (ValueError, OSError):
                pass

    def status(self) -> dict:
        config = settings()
        return {"available": bool(config.get("ANTHROPIC_API_KEY") or config.get("ANTHROPIC_KEY")),
                "remainingGenerations": max(0, 3 - self.calls), "latest": self.latest}

    def run(self, level: str, engine: Callable[[str, str], dict], provider=None) -> dict:
        if level not in {"3", "4"}:
            raise ValueError("The AI experiment supports the old and repaired policies (3 or 4).")
        if not self.lock.acquire(blocking=False):
            raise ValueError("An AI experiment is already running.")
        try:
            if self.calls >= 3:
                raise ValueError("The three-generation demo budget is used. Existing results remain available.")
            self.calls += 1
            feedback = []
            if self.latest:
                feedback = [{"title": a["title"], "moves": a["proposedMoves"],
                             "old": a["old"]["events"], "repaired": a["repaired"]["events"]}
                            for a in self.latest["attempts"]]
            proposer = provider or ClaudeAttacker()
            if self.scenario == "solo":
                model, plans = proposer.propose(level, feedback)
            else:
                model, plans = proposer.propose(level, feedback, scenario=self.scenario)
            plans = validate_attacks({"attacks": plans})
            attempts = [{"title": p["title"], "tactic": p["tactic"], "proposedMoves": p["moves"],
                         "old": evaluate_attack(engine, "3", p),
                         "repaired": evaluate_attack(engine, "4", p)} for p in plans]
            report = {"source": "Anthropic API", "model": model,
                      "generatedAt": datetime.now(timezone.utc).isoformat(),
                      "attackedPolicy": int(level), "scenario": self.scenario,
                      "rulesGiven": public_rules(level, self.scenario),
                      "feedbackUsed": feedback, "attempts": attempts,
                      "note": "The LLM proposed these plans from public rules. Lean judged every move. "
                              "The same plans were replayed against both policies. A failed attack is not a proof of safety."}
            self.latest = report
            if self.cache_path:
                self.cache_path.parent.mkdir(parents=True, exist_ok=True)
                self.cache_path.write_text(json.dumps(report, indent=2))
            return report
        finally:
            self.lock.release()
