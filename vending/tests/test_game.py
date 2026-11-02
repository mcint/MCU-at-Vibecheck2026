from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import threading
import unittest
from http.server import ThreadingHTTPServer
from urllib.error import HTTPError
from urllib.request import Request, urlopen
from unittest.mock import patch
from adversary import Experiment

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from demo import BINARY, Handler, play, run_game


def order_play(level, moves=""):
    return run_game(level, moves, binary=ROOT / ".lake/build/bin/order_game")


class GameAcceptance(unittest.TestCase):
    def test_level_progression(self):
        self.assertEqual([order_play(str(i))["initialCanForce"] for i in range(1, 5)],
                         [True, True, False, True])

    def test_happy_trace_is_not_a_winning_strategy(self):
        game = order_play("3", "pay,capture,ship")
        self.assertTrue(game["settled"])
        self.assertTrue(game["safe"])
        self.assertFalse(game["initialCanForce"])

    def test_broken_counterexample(self):
        game = order_play("3", "pay,requestCancellation,closeCancellation,capture")
        self.assertEqual(game["node"], "chargedAfterClose")
        self.assertFalse(game["safe"])
        self.assertFalse(game["canForce"])

    def test_repaired_late_capture(self):
        game = order_play("4", "pay,requestCancellation,awaitCapture,capture,requestRefund,confirmRefund")
        self.assertEqual(game["node"], "refunded")
        self.assertTrue(game["safe"])
        self.assertTrue(game["settled"])

    def test_repaired_declined_capture(self):
        game = order_play("4", "pay,requestCancellation,awaitCapture,decline")
        self.assertEqual(game["node"], "cancelled")
        self.assertTrue(game["settled"])

    def test_repair_preserves_fulfillment(self):
        self.assertEqual(order_play("4", "pay,capture,ship")["node"], "shipped")

    def test_strategy_does_not_make_every_action_safe(self):
        game = order_play("4", "pay,requestCancellation")
        options = {a["id"]: a["canForce"] for a in game["actions"]}
        self.assertEqual(options, {"closeCancellation": False, "awaitCapture": True})
        self.assertFalse(order_play("4", "pay,requestCancellation,closeCancellation,capture")["safe"])

    def test_cancellation_added_at_level_two(self):
        with self.assertRaises(ValueError):
            order_play("1", "cancel")
        self.assertEqual(order_play("2", "cancel")["node"], "cancelled")

    def test_provider_failure(self):
        self.assertEqual(order_play("3", "pay,decline")["node"], "paymentFailed")

    def test_unknown_moves_are_rejected_not_dropped(self):
        for moves in ["pay,dragon,capture,ship", "pay,,capture", "pay,"]:
            with self.subTest(moves=moves), self.assertRaises(ValueError):
                order_play("3", moves)

    def test_wrong_order_and_post_terminal_moves(self):
        for moves in ["ship", "pay,ship", "cancel,pay", "pay,capture,ship,ship"]:
            with self.subTest(moves=moves), self.assertRaises(ValueError):
                order_play("3", moves)

    def test_all_terminal_outcomes_have_no_actions(self):
        for level, moves in [("1", "pay,ship"), ("2", "cancel"),
                             ("4", "pay,decline"),
                             ("4", "pay,requestCancellation,awaitCapture,capture,requestRefund,confirmRefund")]:
            with self.subTest(moves=moves):
                self.assertEqual(order_play(level, moves)["actions"], [])

    def test_cli_rejects_invalid_level_without_server(self):
        result = subprocess.run([str(ROOT / ".lake/build/bin/order_game"), "play", "99"], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("error", json.loads(result.stdout))


class HTTPAcceptance(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.base = f"http://127.0.0.1:{cls.server.server_port}"

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join(timeout=2)

    def test_page_served(self):
        with urlopen(self.base) as response:
            page = response.read()
            self.assertIn(b"The business rules", page)
            self.assertIn(b"Show why the rule fails", page)

    def test_api_replays_authoritatively(self):
        with urlopen(self.base + "/api/play?level=4&moves=insertCoin,buy,askRefund,waitForMotor,motorJams,returnCoin,coinReturned") as response:
            self.assertEqual(json.load(response)["node"], "refunded")

    def test_api_rejects_state_injection_and_duplicate_parameters(self):
        for query in ["level=4&node=shipped", "level=3&level=4", "level=4&moves=ship"]:
            with self.subTest(query=query), self.assertRaises(HTTPError) as error:
                urlopen(self.base + "/api/play?" + query)
            self.assertEqual(error.exception.code, 400)
            error.exception.close()

    def test_api_enforces_the_proved_machine_rule(self):
        query = "/api/play?level=4&moves=insertCoin,buy,askRefund,returnCoin,motorDelivers"
        with self.assertRaises(HTTPError) as error:
            urlopen(self.base + query)
        self.assertEqual(error.exception.code, 400)
        self.assertIn("machine policy", json.load(error.exception)["error"])
        error.exception.close()

    def test_ai_endpoint_replays_mocked_plans_without_a_paid_call(self):
        class Provider:
            def propose(self, level, feedback):
                return "mock-http-provider", [{"title": "Refund race", "tactic": "Refund during dispensing.",
                    "moves": ["insertCoin", "buy", "askRefund", "motorDelivers"]}]
        request = Request(self.base + "/api/attack", data=b'{"level":"3"}',
                          headers={"Content-Type": "application/json"})
        with patch("demo.AI", Experiment()), patch("adversary.ClaudeAttacker", return_value=Provider()):
            with urlopen(request) as response:
                report = json.load(response)
            self.assertTrue(report["attempts"][0]["old"]["exploitFound"])
            self.assertFalse(report["attempts"][0]["repaired"]["exploitFound"])

    def test_ai_status_does_not_expose_credentials(self):
        with urlopen(self.base + "/api/ai") as response:
            status = json.load(response)
        self.assertEqual(set(status), {"available", "remainingGenerations", "latest"})

    def test_ai_post_rejects_foreign_origin(self):
        request = Request(self.base + "/api/attack", data=b'{"level":"3"}',
                          headers={"Content-Type": "application/json", "Origin": "https://example.com"})
        with self.assertRaises(HTTPError) as error:
            urlopen(request)
        self.assertEqual(error.exception.code, 400)
        error.exception.close()


if __name__ == "__main__":
    unittest.main()
