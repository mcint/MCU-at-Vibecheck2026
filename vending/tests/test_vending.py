import unittest
from pathlib import Path
from demo import play


class VendingAcceptance(unittest.TestCase):
    def test_progression(self):
        self.assertEqual([play(str(i))["initialCanForce"] for i in range(1, 5)],
                         [True, True, False, True])

    def test_normal_purchase_is_still_required(self):
        for level in ("1", "2", "3", "4"):
            game = play(level, "insertCoin,buy,motorDelivers")
            self.assertEqual(game["node"], "served")
            self.assertTrue(game["drinkWithPlayer"])
            self.assertFalse(game["coinWithPlayer"])
            self.assertTrue(game["settled"])

    def test_refund_before_buying(self):
        game = play("2", "insertCoin,askRefund,returnCoin,coinReturned")
        self.assertTrue(game["coinWithPlayer"])
        self.assertFalse(game["drinkWithPlayer"])

    def test_exploit_is_both_coin_and_drink(self):
        game = play("3", "insertCoin,buy,askRefund,returnCoin,motorDelivers")
        self.assertTrue(game["coinWithPlayer"])
        self.assertTrue(game["drinkWithPlayer"])
        self.assertFalse(game["safe"])

    def test_repair_keeps_coin_when_drink_drops(self):
        game = play("4", "insertCoin,buy,askRefund,waitForMotor,motorDelivers")
        self.assertTrue(game["drinkWithPlayer"])
        self.assertFalse(game["coinWithPlayer"])
        self.assertTrue(game["safe"])

    def test_danger_is_detected_before_the_drink_drops(self):
        game = play("3", "insertCoin,buy,askRefund,returnCoin")
        self.assertFalse(game["refundProtected"])
        self.assertTrue(game["coinWithPlayer"])
        self.assertFalse(game["drinkWithPlayer"])

    def test_repair_returns_coin_when_motor_jams(self):
        game = play("4", "insertCoin,buy,askRefund,waitForMotor,motorJams,returnCoin,coinReturned")
        self.assertTrue(game["coinWithPlayer"])
        self.assertFalse(game["drinkWithPlayer"])
        self.assertTrue(game["settled"])

    def test_machine_must_choose_defense(self):
        game = play("4", "insertCoin,buy,askRefund")
        self.assertEqual(game["actor"], "Machine")
        self.assertEqual({a["id"]: a["canForce"] for a in game["actions"]},
                         {"returnCoin": False, "waitForMotor": True})

    def test_bad_actions_are_rejected(self):
        for moves in ("buy", "insertCoin,dragon,buy", "insertCoin,buy,motorDelivers,askRefund"):
            with self.subTest(moves=moves), self.assertRaises(ValueError):
                play("4", moves)

    def test_concrete_machine_rule_covers_every_defined_reply(self):
        pending = [[]]
        visited = set()
        outcomes = set()
        while pending:
            moves = pending.pop()
            game = play("4", ",".join(moves))
            self.assertTrue(game["safe"], moves)
            self.assertTrue(game["refundProtected"], moves)
            self.assertFalse(game["coinWithPlayer"] and game["drinkWithPlayer"], moves)
            if game["node"] in visited:
                continue
            visited.add(game["node"])
            actions = game["actions"]
            if game["actor"] == "Machine":
                actions = [a for a in actions if a["id"] == game["machineChoice"]]
                self.assertEqual(len(actions), 1)
            if not actions:
                self.assertTrue(game["settled"], moves)
                outcomes.add(game["node"])
            pending.extend(moves + [action["id"]] for action in actions)
        self.assertEqual(outcomes, {"served", "refunded"})

    def test_explanation_names_the_policy_proofs(self):
        self.assertEqual(play("3")["policyTheorem"], "broken_policy_violates_promise")
        self.assertEqual(play("4")["policyTheorem"], "repaired_policy_never_gives_both")
        game = play("4", "insertCoin,buy,askRefund")
        self.assertEqual(game["machineChoice"], "waitForMotor")

    def test_failure_demo_uses_a_counterexample_from_the_checker(self):
        initial = play("3")
        witness = initial["counterexample"]
        self.assertEqual(witness, ["insertCoin", "buy", "askRefund", "returnCoin", "motorDelivers"])
        self.assertFalse(play("3", ",".join(witness))["safe"])
        self.assertIsNone(play("4")["counterexample"])

    def test_rule_representations_reference_actual_lean_declarations(self):
        root = Path(__file__).resolve().parents[1]
        declarations = (root / "VendingGame/BusinessRules.lean").read_text() + (root / "VendingGame/Policy.lean").read_text()
        rules = play("4")["businessRules"]
        self.assertEqual(len(rules), 6)
        for rule in rules:
            self.assertIn("theorem " + rule["theorem"], declarations)
            self.assertTrue(rule["representation"])


if __name__ == "__main__":
    unittest.main()
