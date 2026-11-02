import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError
from urllib.request import Request, urlopen

from adversary import ClaudeAttacker, Experiment, public_rules
from demo import run_game
import test_game as existing_http


def rush(level, moves=""):
    return run_game(level, moves, enforce_policy=True, scenario="rush")


PLANS = [
    {"title": "Both buy", "tactic": "Interleave buyers before delivery.",
     "moves": ["insertCoinA", "buyA", "insertCoinB", "buyB"]},
    {"title": "Refund race", "tactic": "Refund during delivery.",
     "moves": ["insertCoinA", "buyA", "askRefundA", "motorDeliversA"]},
    {"title": "Refund replay", "tactic": "Repeat the completed refund.",
     "moves": ["insertCoinB", "askRefundB", "retryRefundB"]},
]


class RushProvider:
    def propose(self, level, feedback, scenario="solo"):
        if scenario != "rush":
            raise AssertionError("Wrong rule bundle")
        return "mock-rush-attacker", copy.deepcopy(PLANS)


class RushAcceptance(unittest.TestCase):
    def test_three_distinct_old_policy_violations_and_paired_repairs(self):
        expected = ["Last drink reserved twice", "Drink delivered after refund", "Same refund paid twice"]
        report = Experiment(scenario="rush").run("3", rush, RushProvider())
        for plan, violation in zip(PLANS, expected):
            with self.subTest(plan=plan["title"]):
                attempt = next(a for a in report["attempts"] if a["title"] == plan["title"])
                self.assertTrue(attempt["old"]["exploitFound"])
                self.assertEqual(attempt["old"]["violations"], [violation])
                self.assertFalse(attempt["repaired"]["exploitFound"])

    def test_repaired_double_booking_rejects_only_conflicting_buy(self):
        before = rush("4", "insertCoinA,buyA,insertCoinB")
        self.assertEqual(before["claims"], 1)
        self.assertNotIn("buyB", [a["id"] for a in before["actions"]])
        with self.assertRaises(ValueError):
            rush("4", "insertCoinA,buyA,insertCoinB,buyB")
        self.assertEqual(rush("4", "insertCoinA,buyA,insertCoinB,askRefundB")["buyers"][1]["phase"], "refunded")

    def test_successful_orders_remain_possible_for_both_buyers(self):
        for buyer in ("A", "B"):
            g = rush("4", f"insertCoin{buyer},buy{buyer},motorDelivers{buyer}")
            self.assertTrue(g["safe"])
            self.assertTrue(next(b for b in g["buyers"] if b["id"] == buyer)["drink"])

    def test_jam_releases_capacity_and_cannot_refund_the_other_buyer(self):
        g = rush("4", "insertCoinA,buyA,insertCoinB,askRefundA,motorJamsA,buyB,motorDeliversB")
        self.assertEqual([b["phase"] for b in g["buyers"]], ["refunded", "served"])
        self.assertEqual(g["claims"], 1)
        self.assertTrue(all(g["promises"].values()))

    def test_refund_retry_is_an_accepted_idempotent_loop(self):
        moves = "insertCoinA,askRefundA," + ",".join(["retryRefundA"] * 20)
        g = rush("4", moves)
        self.assertEqual(g["buyers"][0]["refunds"], 1)
        self.assertTrue(g["safe"])
        self.assertEqual(len(g["moves"]), 22)

    def test_callbacks_require_the_named_buyers_own_running_order(self):
        for moves in ["motorDeliversA", "insertCoinA,buyA,motorDeliversB",
                      "insertCoinA,retryRefundA", "insertCoinA,buyA,motorDeliversA,motorDeliversA",
                      "insertCoinA,dragon,buyA"]:
            with self.subTest(moves=moves), self.assertRaises(ValueError):
                rush("4", moves)

    def test_native_challenges_and_formal_rows_are_bound_to_declarations(self):
        g = rush("3")
        self.assertEqual(g["formalState"], "⟨.idle, .idle⟩")
        self.assertIn("RushGame.old_double_books", g["policyTheorem"])
        self.assertEqual(rush("4")["policyTheorem"], "RushGame.repaired_all_promises")
        self.assertEqual(len(g["challenges"]), 3)
        source = (Path(__file__).resolve().parents[1] / "RushGame/Verify.lean").read_text()
        for rule in g["businessRules"]:
            self.assertIn("theorem " + rule["theorem"].split(".")[-1], source)
        for challenge in g["challenges"]:
            self.assertFalse(rush("3", ",".join(challenge["moves"]))["safe"])

    def test_prompt_and_cache_are_isolated_by_scenario(self):
        rules = public_rules("3", "rush")
        self.assertEqual(len(rules["player_actions"]), 12)
        for hint in ("counterexample", "repaired_all_promises", "old_double_books", "challenges"):
            self.assertNotIn(hint, json.dumps(rules))
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "report.json"
            Experiment(path, scenario="rush").run("3", rush, RushProvider())
            self.assertIsNone(Experiment(path).latest)
            self.assertEqual(Experiment(path, scenario="rush").latest["scenario"], "rush")

    def test_provider_receives_only_rush_rules_for_rush_generation(self):
        response = {"model": "test", "content": [{"type": "tool_use", "name": "submit_attacks",
                    "input": {"attacks": PLANS}}]}
        with patch("adversary.settings", return_value={"ANTHROPIC_MODEL": "test"}), \
             patch.object(ClaudeAttacker, "request", return_value=response) as request:
            ClaudeAttacker().propose("3", [], scenario="rush")
        prompt = json.loads(request.call_args.args[1]["messages"][0]["content"])
        self.assertEqual(prompt, public_rules("3", "rush"))


class RushHTTPAcceptance(unittest.TestCase):
    setUpClass = classmethod(existing_http.HTTPAcceptance.setUpClass.__func__)
    tearDownClass = classmethod(existing_http.HTTPAcceptance.tearDownClass.__func__)

    def test_rush_api_dispatch_and_invalid_scenarios(self):
        with urlopen(self.base + "/api/play?scenario=rush&level=3&moves=insertCoinA,buyA,insertCoinB,buyB") as r:
            self.assertEqual(json.load(r)["violations"], ["Last drink reserved twice"])
        for query in ("scenario=bad&level=4", "scenario=rush&scenario=solo&level=4", "scenario=rush&level=1"):
            with self.subTest(query=query), self.assertRaises(HTTPError) as error:
                urlopen(self.base + "/api/play?" + query)
            self.assertEqual(error.exception.code, 400)
            error.exception.close()

    def test_rush_ai_post_and_type_validation(self):
        request = Request(self.base + "/api/attack", data=b'{"level":"3","scenario":"rush"}',
                          headers={"Content-Type": "application/json"})
        with patch("demo.RUSH_AI", Experiment(scenario="rush")), patch("adversary.ClaudeAttacker", return_value=RushProvider()):
            with urlopen(request) as response:
                report = json.load(response)
            self.assertEqual(report["scenario"], "rush")
            self.assertTrue(all(a["old"]["exploitFound"] and not a["repaired"]["exploitFound"] for a in report["attempts"]))
        for scenario in ([], {}, 1, None, "wrong"):
            bad = Request(self.base + "/api/attack", data=json.dumps({"level": "3", "scenario": scenario}).encode(),
                          headers={"Content-Type": "application/json"})
            with self.subTest(scenario=scenario), self.assertRaises(HTTPError) as error:
                urlopen(bad)
            self.assertEqual(error.exception.code, 400)
            error.exception.close()
