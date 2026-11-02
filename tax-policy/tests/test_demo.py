import copy
from http.server import ThreadingHTTPServer
import json
import tempfile
import threading
import unittest
from unittest.mock import patch
from urllib.error import HTTPError
from urllib.request import Request, urlopen
from pathlib import Path

from demo import engine, audit, discount, interdomain, Handler, Rejected
from adversary import Claude, Experiment, public_rules, validate

PLANS = [
    {"title": "A raise hurts", "tactic": "Cross the housing support cutoff.", "wages": 1199, "side": 0, "moves": ["raise1"]},
    {"title": "Same total, different label", "tactic": "Reclassify work income.", "wages": 1000, "side": 0, "moves": ["shift100"]},
    {"title": "Retry pays again", "tactic": "Repeat the same support assessment.", "wages": 999, "side": 0, "moves": ["file", "retry"]},
]
class Provider:
    def propose(self, policy):
        return "mock-test-provider", copy.deepcopy(PLANS)


class Native(unittest.TestCase):
    def test_interdomain_witness_and_repair_accounting(self):
        d = interdomain()
        self.assertEqual(d["source"], "Native Lean evaluation of the modeled 2026 PTC rules")
        self.assertEqual((d["fpl"], d["cutoff"], d["benchmarkPremium"]), (15650, 62600, 661))
        self.assertEqual(d["witnessIncome"], 62600)
        self.assertEqual((d["before"]["credit"], d["before"]["premium"]), (141, 520))
        self.assertEqual((d["after"]["credit"], d["after"]["premium"]), (0, 661))
        self.assertEqual((d["before"]["annualContribution"], d["before"]["monthlyContribution"]), (6235, 520))
        self.assertEqual((d["before"]["annualIncomeAfterPremium"], d["after"]["annualIncomeAfterPremium"]), (56360, 54669))
        self.assertEqual(d["annualCreditLoss"], 1692)
        self.assertEqual((d["proposedBefore"]["premium"], d["proposedAfter"]["premium"]), (520, 520))
        points = {p["income"]: p for p in d["curve"]}
        self.assertEqual(sorted(points), list(range(62450, 62751)))
        self.assertEqual((points[62600]["current"], points[62601]["current"]), (520, 661))
        self.assertEqual((points[62600]["proposed"], points[62601]["proposed"]), (520, 520))
        self.assertEqual((points[62600]["currentPTC"], points[62601]["currentPTC"]), (141, 0))
        self.assertEqual((points[62600]["proposedPTC"], points[62601]["proposedPTC"]), (141, 141))
        self.assertEqual(d["proof"], "TaxGame.Interdomain.real_cutoff_cliff")
        self.assertEqual(d["repairProof"], "TaxGame.Interdomain.proposed_boundary_continuous")
        self.assertEqual(d["searchSoundness"], "TaxGame.Interdomain.found_cliff_is_failure")

    def test_new_discount_policy_matches_source_case_and_preserves_valid_claims(self):
        d = discount(100, 50)
        self.assertEqual((d["actualDiscount"], d["limit"], d["qualifiedPortion"], d["aboveCap"]), (50, 20, 20, 30))
        self.assertFalse(d["claimWithinCap"])
        self.assertTrue(d["fixedWithinCap"] and d["fixedWithinDiscount"])
        self.assertEqual(discount(100, 90)["qualifiedPortion"], 10)
        self.assertEqual(discount(100, 100)["qualifiedPortion"], 0)
        for args in [(101, 50), (0, 0), (100, 101), (100, -1)]:
            with self.subTest(args=args), self.assertRaises(Rejected): discount(*args)

    def test_native_audit_searches_and_returns_real_witnesses(self):
        for kind in ["cliff", "source", "retry"]:
            with self.subTest(kind=kind):
                d = audit(kind)
                self.assertEqual(d["source"], "Lean model search")
                self.assertFalse(d["oldResult"]["safe"])
                self.assertTrue(d["fixedResult"]["safe"])
                self.assertTrue(d["searchSoundness"].startswith("TaxGame.Audit.found_"))
                self.assertGreaterEqual(d["wages"], 0)
                self.assertLessEqual(d["wages"], 2500)
                self.assertEqual(engine("old", d["wages"], d["side"], d["moves"])["formalState"], d["oldResult"]["formalState"])
                self.assertEqual(engine("fixed", d["wages"], d["side"], d["moves"])["formalState"], d["fixedResult"]["formalState"])

    def test_one_dollar_raise_and_fixed_floor(self):
        old = engine("old", 1199, 0)
        bad = engine("old", 1199, 0, ["raise1"])
        fixed = engine("fixed", 1199, 0, ["raise1"])
        self.assertEqual((old["resources"], bad["resources"]), (1480, 1080))
        self.assertFalse(bad["promises"]["noCliff"])
        self.assertFalse(bad["promises"]["floor"])
        self.assertTrue(all(fixed["promises"].values()))

    def test_causal_rows_use_native_before_and_after_values(self):
        old = engine("old", 1199, 0, ["raise1"])
        self.assertEqual([(r["before"], r["after"]) for r in old["causes"]],
                         [(1199, 1200), (119, 120), (400, 0), (1480, 1080)])
        self.assertIn("oldHousingSupport 1200 = 0", old["causes"][2]["lean"])
        fixed = engine("fixed", 1199, 0, ["raise1"])
        self.assertEqual((fixed["beforeResources"], fixed["resources"]), (1740, 1740))
        paid = engine("old", 999, 0, ["file", "retry"])
        self.assertEqual((paid["causes"][2]["before"], paid["causes"][2]["after"]), (1, 2))
        self.assertEqual(paid["causes"][2]["unit"], "count")

    def test_income_label_loophole_and_source_neutral_repair(self):
        for policy in ("old", "fixed"):
            before, after = engine(policy, 1000, 0), engine(policy, 1000, 0, ["shift100"])
            self.assertEqual(before["earnings"], after["earnings"])
            if policy == "old":
                self.assertEqual(after["resources"] - before["resources"], 600)
                self.assertFalse(after["promises"]["fairSources"])
            else:
                self.assertEqual(after["resources"], before["resources"])
                self.assertTrue(after["safe"])

    def test_duplicate_assessment_and_long_idempotent_retry(self):
        old = engine("old", 999, 0, ["file", "retry"])
        self.assertEqual(old["paid"], 2000)
        self.assertFalse(old["promises"]["budget"])
        self.assertFalse(old["promises"]["paidOnce"])
        fixed = engine("fixed", 999, 0, ["file"] + ["retry"] * 23)
        self.assertEqual((fixed["payments"], fixed["paid"]), (1, 750))
        self.assertTrue(fixed["safe"])

    def test_assessment_freezes_income_and_retries_require_filing(self):
        for moves in (["retry"], ["file", "raise1"], ["file", "shift100"]):
            with self.subTest(moves=moves), self.assertRaises(Rejected) as e:
                engine("fixed", 1199, 0, moves)
            self.assertEqual(e.exception.kind, "transition")
        with self.assertRaises(Rejected) as e:
            engine("fixed", 1199, 0, ["file"] * 25)
        self.assertEqual(e.exception.kind, "input")

    def test_actual_github_evaluator_and_source_case(self):
        for wages, side in [(0, 0), (999, 0), (1000, 0), (1199, 0), (1200, 0), (900, 100), (5000, 5000)]:
            with self.subTest(wages=wages, side=side):
                g = engine("old", wages, side)
                self.assertTrue(g["github"]["agrees"])
                self.assertEqual(float(g["github"]["contractAmount"]), g["support"])
                self.assertTrue(g["github"]["trace"])
                self.assertEqual(g["github"]["catalaCap"], 20)

    def test_positive_controls_at_policy_boundaries(self):
        for wages in [0, 1, 999, 1000, 1199, 1200, 2399, 2400, 5000]:
            with self.subTest(wages=wages):
                g = engine("fixed", wages, 0, ["raise100", "file", "retry"])
                self.assertTrue(g["safe"])
                self.assertGreaterEqual(g["resources"], 1200)
                self.assertLessEqual(g["paid"], 1200)

    def test_reject_malformed_inputs(self):
        for args in [("bad", 0, 0, []), ("old", -1, 0, []), ("old", 5001, 0, []),
                     ("old", True, 0, []), ("old", 1000, 0, ["dragon"]),
                     ("old", 1000, 0, ["file,retry"])]:
            with self.subTest(args=args), self.assertRaises(ValueError):
                engine(*args)


class Attacker(unittest.TestCase):
    def test_real_native_adjudication_of_mocked_plans(self):
        d = Experiment().run("old", engine, Provider())
        self.assertTrue(all(a["old"]["exploitFound"] and not a["fixed"]["exploitFound"] for a in d["attempts"]))
        self.assertEqual(d["rulesGiven"], public_rules("old"))

    def test_model_request_contains_only_public_rules(self):
        response = {"model": "test", "content": [{"type": "tool_use", "name": "submit_plans", "input": {"plans": PLANS}}]}
        with patch("adversary.settings", return_value={"ANTHROPIC_MODEL": "test"}), patch.object(Claude, "request", return_value=response) as request:
            Claude().propose("old")
        d = request.call_args.args[1]
        self.assertEqual(d["max_tokens"], 1400)
        self.assertEqual(json.loads(d["messages"][0]["content"]), public_rules("old"))
        self.assertNotIn("theorem", json.dumps(public_rules("old")))

    def test_schema_and_budget_and_explicit_provider_failure(self):
        for invalid in [[], [dict(PLANS[0], success=True)], [dict(PLANS[0], wages=True)], [dict(PLANS[0], moves=["file"] * 9)]]:
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                validate(invalid)
        session = Experiment()
        for _ in range(3): session.run("old", engine, Provider())
        with self.assertRaises(ValueError): session.run("old", engine, Provider())
        p = Provider()
        with patch.object(p, "propose", side_effect=RuntimeError("offline")):
            session = Experiment()
            with self.assertRaises(RuntimeError): session.run("old", engine, p)
            self.assertIsNone(session.latest)


class HTTP(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.base = f"http://127.0.0.1:{cls.server.server_port}"
    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown(); cls.server.server_close(); cls.thread.join(timeout=2)

    def test_page_and_native_replay_and_sources(self):
        with urlopen(self.base) as r: self.assertIn(b"FOLLOW THE MONEY", r.read())
        with urlopen(self.base + "/api/play?policy=old&wages=1199&side=0&moves=raise1") as r:
            self.assertEqual(json.load(r)["resources"], 1080)
        with urlopen(self.base + "/api/sources") as r:
            source = json.load(r)
            self.assertIn("namespace LeanContracts", source["leanContracts"])
            self.assertIn("20%", source["catala"])
            self.assertIn("theorem repaired_floor", source["proof"])

    def test_interdomain_http_and_query_rejection(self):
        with urlopen(self.base + "/api/interdomain") as r:
            self.assertEqual(json.load(r)["after"]["premium"], 661)
        with urlopen(self.base + "/api/sources") as r:
            self.assertIn("theorem real_cutoff_cliff", json.load(r)["interdomainProof"])
        for query in ["wages=1000", "wages=1199&wages=1200", "paid=0"]:
            with self.subTest(query=query), self.assertRaises(HTTPError) as e:
                urlopen(self.base + "/api/interdomain?" + query)
            self.assertEqual(e.exception.code, 400)
            e.exception.close()

    def test_interdomain_engine_failure_is_service_unavailable(self):
        with patch("demo.interdomain", side_effect=RuntimeError("internal diagnostic")):
            with self.assertRaises(HTTPError) as e:
                urlopen(self.base + "/api/interdomain")
            self.assertEqual(e.exception.code, 503)
            self.assertNotIn("internal diagnostic", e.exception.read().decode())
            e.exception.close()

    def test_input_injection_duplicate_fields_and_unknown_moves(self):
        for q in ["policy=old&paid=0", "policy=old&policy=fixed", "wages=-1", "moves=dragon", "moves=file,,retry"]:
            with self.subTest(q=q), self.assertRaises(HTTPError) as e:
                urlopen(self.base + "/api/play?" + q)
            self.assertEqual(e.exception.code, 400); e.exception.close()

    def test_mocked_ai_http_and_foreign_origin_rejection(self):
        req = Request(self.base + "/api/attack", data=b'{"policy":"old"}', headers={"Content-Type": "application/json"})
        with patch("demo.AI", Experiment()), patch("adversary.Claude", return_value=Provider()):
            with urlopen(req) as r: self.assertEqual(len(json.load(r)["attempts"]), 3)
        bad = Request(self.base + "/api/attack", data=b'{"policy":"old"}', headers={"Content-Type": "application/json", "Origin": "https://example.com"})
        with self.assertRaises(HTTPError) as e: urlopen(bad)
        self.assertEqual(e.exception.code, 400); e.exception.close()

    def test_new_discount_policy_http(self):
        with urlopen(self.base + "/api/discount?price=100&employee=50") as r:
            self.assertEqual(json.load(r)["qualifiedPortion"], 20)
        for q in ["price=101&employee=50", "price=100&employee=101", "price=100&employee=50&paid=0"]:
            with self.subTest(q=q), self.assertRaises(HTTPError) as e:
                urlopen(self.base + "/api/discount?" + q)
            self.assertEqual(e.exception.code, 400); e.exception.close()

    def test_native_audit_http_and_strict_input(self):
        with urlopen(self.base + "/api/audit?kind=cliff") as r:
            d = json.load(r)
            self.assertEqual(d["wages"], 1199)
            self.assertEqual(d["oldResult"]["resources"], 1080)
        for query in ("kind=bad", "kind=cliff&kind=retry", "kind=cliff&source=anything", ""):
            with self.subTest(query=query), self.assertRaises(HTTPError) as e:
                urlopen(self.base + "/api/audit?" + query)
            self.assertEqual(e.exception.code, 400)
            e.exception.close()

    def test_ptc_slider_endpoint_and_demo_page(self):
        with urlopen(self.base + "/demo") as r:
            self.assertIn(b"proposed_no_cliff", r.read())
        with urlopen(self.base + "/api/ptc?income=62600") as r:
            d = json.load(r)
            self.assertEqual(r.headers["Access-Control-Allow-Origin"], "*")
            self.assertEqual((d["currentRaiseCost"], d["proposedRaiseCost"], d["proposedNoCliffHolds"]), (141, 0, True))
            self.assertEqual(d["currentAfterRaise"]["premium"], 661)
        with urlopen(self.base + "/api/ptc?income=70000") as r:
            d = json.load(r)
            self.assertTrue(d["aboveCutoff"] and d["current"]["credit"] == 0 and d["proposed"]["credit"] == 8)
        for q in ("income=-1", "income=abc", "income=9999999", "income=1&income=2", "wages=1", ""):
            with self.subTest(q=q), self.assertRaises(HTTPError) as e:
                urlopen(self.base + "/api/ptc?" + q)
            self.assertEqual(e.exception.code, 400); e.exception.close()

    def test_status_never_exposes_key(self):
        with urlopen(self.base + "/api/ai") as r:
            self.assertEqual(set(json.load(r)), {"available", "remaining", "latest"})

if __name__ == "__main__": unittest.main()
