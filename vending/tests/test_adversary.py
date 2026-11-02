import copy
import json
from pathlib import Path
import unittest
from unittest.mock import patch

from adversary import ClaudeAttacker, Experiment, evaluate_attack, public_rules, validate_attacks
from demo import run_game


PLAN = {"title": "Refund while dispensing", "tactic": "Ask for the coin while the motor is still running.",
        "moves": ["insertCoin", "buy", "askRefund", "motorDelivers"]}


def engine(level, moves):
    return run_game(level, moves, enforce_policy=True)


class FakeProvider:
    def __init__(self):
        self.feedback = []

    def propose(self, level, feedback):
        self.feedback.append(copy.deepcopy(feedback))
        return "mock-provider-for-tests", [copy.deepcopy(PLAN)]


class AdversaryAcceptance(unittest.TestCase):
    def test_identical_llm_plan_is_judged_differently_by_the_two_policies(self):
        result = Experiment().run("3", engine, FakeProvider())
        attempt = result["attempts"][0]
        self.assertEqual(attempt["proposedMoves"], PLAN["moves"])
        self.assertTrue(attempt["old"]["exploitFound"])
        self.assertFalse(attempt["repaired"]["exploitFound"])
        self.assertEqual([e["action"] for e in attempt["old"]["events"] if e["actor"] == "Machine rule"], ["returnCoin"])
        self.assertEqual([e["action"] for e in attempt["repaired"]["events"] if e["actor"] == "Machine rule"], ["waitForMotor"])

    def test_illegal_action_is_reported_not_dropped(self):
        plan = dict(PLAN, moves=["insertCoin", "dragon", "buy"])
        result = evaluate_attack(engine, "3", plan)
        self.assertFalse(result["exploitFound"])
        self.assertEqual(result["moves"], ["insertCoin"])
        self.assertFalse(result["events"][-1]["accepted"])

    def test_attacker_cannot_select_machine_actions(self):
        plan = dict(PLAN, moves=["insertCoin", "buy", "askRefund", "returnCoin", "motorDelivers"])
        result = evaluate_attack(engine, "4", plan)
        self.assertFalse(result["exploitFound"])
        self.assertFalse(result["events"][-1]["accepted"])
        self.assertNotIn("returnCoin", result["moves"])

    def test_prompt_contains_rules_without_solver_answers(self):
        encoded = json.dumps(public_rules("3"))
        for private_hint in ("counterexample", "canForce", "wins", "broken_no_strategy", "findFailure"):
            self.assertNotIn(private_hint, encoded)
        self.assertIn("rules", public_rules("3"))
        self.assertIn("scheduler", encoded)

    def test_untrusted_schema_and_move_bounds(self):
        for payload in [None, {"attacks": []}, {"attacks": [dict(PLAN, success=True)]},
                        {"attacks": [dict(PLAN, moves=["insertCoin,buy"])]},
                        {"attacks": [dict(PLAN, moves=["buy"] * 13)]}]:
            with self.subTest(payload=payload), self.assertRaises(ValueError):
                validate_attacks(payload)

    def test_generation_budget_and_observable_feedback(self):
        session, provider = Experiment(), FakeProvider()
        for _ in range(3):
            session.run("3", engine, provider)
        self.assertEqual(provider.feedback[0], [])
        self.assertTrue(provider.feedback[1])
        with self.assertRaises(ValueError):
            session.run("3", engine, provider)

    def test_provider_failure_does_not_create_fake_success(self):
        provider = FakeProvider()
        with patch.object(provider, "propose", side_effect=RuntimeError("Provider unavailable")):
            session = Experiment()
            with self.assertRaises(RuntimeError):
                session.run("3", engine, provider)
            self.assertIsNone(session.latest)

    def test_messages_request_contains_only_public_game_context(self):
        response = {"model": "test-model", "content": [{"type": "tool_use", "name": "submit_attacks", "input": {"attacks": [PLAN]}}]}
        with patch("adversary.settings", return_value={"ANTHROPIC_MODEL": "test-model"}), \
             patch.object(ClaudeAttacker, "request", return_value=response) as request:
            model, plans = ClaudeAttacker().propose("3", [])
        self.assertEqual(model, "test-model")
        self.assertEqual(plans[0]["moves"], PLAN["moves"])
        request_body = request.call_args.args[1]
        self.assertEqual(request_body["max_tokens"], 1400)
        prompt = json.loads(request_body["messages"][0]["content"])
        self.assertEqual(prompt, public_rules("3"))


if __name__ == "__main__":
    unittest.main()
