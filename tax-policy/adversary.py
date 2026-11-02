"""Bounded Claude counterexample search. Native Lean adjudicates every action."""
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import threading
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

ROOT = Path(__file__).resolve().parent
ACTIONS = {"raise1", "raise100", "shift100", "file", "retry"}


def settings():
    names = {"ANTHROPIC_API_KEY", "ANTHROPIC_KEY", "ANTHROPIC_MODEL"}
    result = {k: os.environ[k] for k in names if os.environ.get(k)}
    for path in (ROOT.parents[1] / ".env", ROOT.parents[2] / ".env"):
        if path.is_file():
            for line in path.read_text().splitlines():
                k, sep, value = line.strip().removeprefix("export ").partition("=")
                if sep and k.strip() in names:
                    value = value.strip()
                    if len(value) > 1 and value[0] == value[-1] and value[0] in "\"'":
                        value = value[1:-1]
                    result.setdefault(k.strip(), value)
    return result


def public_rules(policy):
    return {"policy": policy, "fictional": True,
        "goal": "Find a starting household and actions violating any promise: resources at least 1200; raises do not reduce resources; equal total work earnings are treated equally; no more than 1200 disbursed; one support award per assessment.",
        "rules": ["One household. Starting wages and side income each range from 0 to 5000 whole units.",
            "Total work earnings are wages plus side income. Tax is total earnings divided by 10, rounded down.",
            ("Old support: 600 if wages are below 1000, plus 400 if total earnings are below 1200. Side income is excluded from the first test."
             if policy == "old" else "Repaired support: max(0, 1200 - floor(net work earnings / 2)). Net work earnings are total earnings minus tax."),
            "Resources mean net earnings plus eligible support. Disbursed cash is tracked separately.",
            "Income can change before filing; after filing this period's assessment is fixed.",
            ("Each old filing or retry pays the eligible support again." if policy == "old" else "The first repaired filing pays support once; later filings and retries acknowledge it without another payment."),
            "This is a fictional model, not tax advice or a claim about current legislation."],
        "actions": {"raise1": "Add 1 to wages", "raise100": "Add 100 to wages",
                    "shift100": "Move 100 from wages to side work, preserving total; requires wages >= 100",
                    "file": "File for support", "retry": "Retry a previously filed assessment"}}


def validate(plans):
    if not isinstance(plans, list) or not 1 <= len(plans) <= 3:
        raise ValueError("Provide one to three plans.")
    for p in plans:
        if not isinstance(p, dict) or set(p) != {"title", "tactic", "wages", "side", "moves"}:
            raise ValueError("Invalid plan fields.")
        for name, limit in (("title", 80), ("tactic", 240)):
            if not isinstance(p[name], str) or not 1 <= len(p[name]) <= limit:
                raise ValueError("Invalid plan description.")
        for name in ("wages", "side"):
            if type(p[name]) is not int or not 0 <= p[name] <= 5000:
                raise ValueError("Starting income must be an integer from 0 to 5000.")
        if not isinstance(p["moves"], list) or not 1 <= len(p["moves"]) <= 8:
            raise ValueError("A plan requires one to eight actions.")
        if any(not isinstance(a, str) or not 1 <= len(a) <= 40 or "," in a for a in p["moves"]):
            raise ValueError("Invalid action value.")
    return plans


class Claude:
    def request(self, path, body=None):
        config = settings()
        key = config.get("ANTHROPIC_API_KEY") or config.get("ANTHROPIC_KEY")
        if not key:
            raise RuntimeError("No server-side Anthropic key configured. Checked examples still work.")
        request = Request("https://api.anthropic.com/v1" + path,
            data=None if body is None else json.dumps(body).encode(),
            headers={"x-api-key": key, "anthropic-version": "2023-06-01", "content-type": "application/json"})
        try:
            with urlopen(request, timeout=45) as response:
                return json.load(response)
        except HTTPError as e:
            code = e.code
            e.close()
            raise RuntimeError(f"Anthropic returned HTTP {code}. No simulated result was substituted.") from None
        except (URLError, TimeoutError):
            raise RuntimeError("Anthropic could not be reached. No simulated result was substituted.") from None

    def propose(self, policy):
        model = settings().get("ANTHROPIC_MODEL")
        if not model:
            available = [x["id"] for x in self.request("/models?limit=100").get("data", [])]
            model = next((m for m in available if "haiku" in m), None) or next(iter(available), None)
        if not model:
            raise RuntimeError("No available model found.")
        schema = {"type": "object", "additionalProperties": False, "required": ["plans"], "properties": {
            "plans": {"type": "array", "minItems": 1, "maxItems": 3, "items": {
                "type": "object", "additionalProperties": False,
                "required": ["title", "tactic", "wages", "side", "moves"], "properties": {
                    "title": {"type": "string", "maxLength": 80}, "tactic": {"type": "string", "maxLength": 240},
                    "wages": {"type": "integer", "minimum": 0, "maximum": 5000},
                    "side": {"type": "integer", "minimum": 0, "maximum": 5000},
                    "moves": {"type": "array", "minItems": 1, "maxItems": 8, "items": {"type": "string", "maxLength": 40}}}}}}}
        d = self.request("/messages", {"model": model, "max_tokens": 1400,
            "system": "Find counterexamples in this fictional tax-benefit game. Propose up to three diverse short plans. Give a brief tactic, not hidden reasoning. Do not claim success; an independent engine judges each plan. Do not invent actions or alter rules.",
            "messages": [{"role": "user", "content": json.dumps(public_rules(policy))}],
            "tools": [{"name": "submit_plans", "description": "Submit household/action counterexamples.", "input_schema": schema}],
            "tool_choice": {"type": "tool", "name": "submit_plans"}})
        blocks = [b for b in d.get("content", []) if b.get("type") == "tool_use" and b.get("name") == "submit_plans"]
        if len(blocks) != 1 or not isinstance(blocks[0].get("input"), dict) or set(blocks[0]["input"]) != {"plans"}:
            raise RuntimeError("The model did not provide structured plans.")
        return d.get("model", model), validate(blocks[0]["input"]["plans"])


def evaluate(engine, policy, plan):
    moves, events = [], []
    game = engine(policy, plan["wages"], plan["side"], moves)
    for action in plan["moves"]:
        try:
            next_game = engine(policy, plan["wages"], plan["side"], moves + [action])
        except ValueError as e:
            events.append({"action": action, "accepted": False, "reason": str(e)})
            break
        events.append({"action": action, "accepted": True, "before": game["formalState"],
                       "after": next_game["formalState"], "resources": next_game["resources"],
                       "violations": next_game["violations"]})
        moves.append(action)
        game = next_game
        if not game["safe"]:
            break
    return {"events": events, "moves": moves, "resources": game["resources"],
            "violations": game["violations"], "exploitFound": not game["safe"]}


class Experiment:
    def __init__(self, cache=None):
        self.cache, self.latest, self.calls = cache, None, 0
        self.lock = threading.Lock()
        if cache and cache.is_file():
            try:
                d = json.loads(cache.read_text())
                if d.get("source") == "Anthropic API" and d.get("scenario") == "tax":
                    self.latest = d
            except (ValueError, OSError, AttributeError):
                pass

    def status(self):
        c = settings()
        return {"available": bool(c.get("ANTHROPIC_API_KEY") or c.get("ANTHROPIC_KEY")),
                "remaining": max(0, 3 - self.calls), "latest": self.latest}

    def run(self, policy, engine, provider=None):
        if policy not in {"old", "fixed"}:
            raise ValueError("Choose old or fixed.")
        if not self.lock.acquire(blocking=False):
            raise ValueError("An AI round is already running.")
        try:
            if self.calls >= 3:
                raise ValueError("The three-round budget is used. Recorded runs remain available.")
            self.calls += 1
            model, plans = (provider or Claude()).propose(policy)
            plans = validate(plans)
            result = {"source": "Anthropic API", "scenario": "tax", "model": model,
                "generatedAt": datetime.now(timezone.utc).isoformat(), "attackedPolicy": policy,
                "rulesGiven": public_rules(policy), "attempts": [dict(p, old=evaluate(engine, "old", p),
                fixed=evaluate(engine, "fixed", p)) for p in plans],
                "note": "Actual Claude plans, paired native Lean replay. Failed attacks do not establish safety; the exact model has separate kernel-checked proofs."}
            self.latest = result
            if self.cache:
                self.cache.parent.mkdir(exist_ok=True)
                self.cache.write_text(json.dumps(result, indent=2))
            return result
        finally:
            self.lock.release()
