#!/usr/bin/env python3
"""Standalone, loopback-only fictional tax-benefit game. Lean owns outcomes."""
import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import subprocess
from urllib.parse import urlsplit, parse_qs
from adversary import Experiment

ROOT = Path(__file__).resolve().parent
BINARY = ROOT / ".lake/build/bin/tax_game"
AI = Experiment(ROOT / "runs/tax-ai-latest.json")

class Rejected(ValueError):
    def __init__(self, message, kind="input"):
        super().__init__(message)
        self.kind = kind


def engine(policy, wages=1199, side=0, moves=None):
    moves = [] if moves is None else moves
    if policy not in {"old", "fixed"} or any(type(n) is not int or not 0 <= n <= 5000 for n in (wages, side)):
        raise Rejected("Choose old/fixed and starting incomes from 0 to 5000.")
    if not isinstance(moves, list) or len(moves) > 24 or any(not isinstance(a, str) or not 1 <= len(a) <= 40 or "," in a for a in moves):
        raise Rejected("Provide at most 24 individual actions.")
    r = subprocess.run([str(BINARY), "play", policy, str(wages), str(side), ",".join(moves)],
                        cwd=ROOT, capture_output=True, text=True, timeout=10)
    try:
        d = json.loads(r.stdout)
    except ValueError:
        raise RuntimeError("The native Lean engine returned no valid result.") from None
    if r.returncode:
        raise Rejected(d.get("error", "Move rejected."), d.get("errorKind", "input"))
    return d


def audit(kind):
    if not isinstance(kind, str) or kind not in {"cliff", "source", "retry"}:
        raise Rejected("Choose cliff, source, or retry.")
    r = subprocess.run([str(BINARY), "audit", kind], cwd=ROOT,
                       capture_output=True, text=True, timeout=10)
    try:
        d = json.loads(r.stdout)
    except ValueError:
        raise RuntimeError("The Lean audit returned no valid result.") from None
    if r.returncode:
        raise Rejected(d.get("error", "No witness found."), d.get("errorKind", "input"))
    return d


def interdomain():
    r = subprocess.run([str(BINARY), "interdomain"], cwd=ROOT,
                       capture_output=True, text=True, timeout=10)
    try:
        d = json.loads(r.stdout)
    except ValueError:
        raise RuntimeError("The Lean inter-domain evaluator returned no valid result.") from None
    if r.returncode:
        raise RuntimeError(d.get("error", "No inter-domain witness found."))
    return d


def ptc(income):
    if type(income) is not int or not 0 <= income <= 200000:
        raise Rejected("Annual MAGI must be a whole-dollar amount from 0 to 200000.")
    r = subprocess.run([str(BINARY), "ptc", str(income)], cwd=ROOT,
                       capture_output=True, text=True, timeout=10)
    try:
        d = json.loads(r.stdout)
    except ValueError:
        raise RuntimeError("The Lean PTC evaluator returned no valid result.") from None
    if r.returncode:
        raise Rejected(d.get("error", "Invalid income."))
    return d


def discount(price, employee):
    if type(price) is not int or type(employee) is not int or not 5 <= price <= 10000 or price % 5 or not 0 <= employee <= price:
        raise Rejected("Use a customer price divisible by 5 and an employee price between 0 and that price.")
    r = subprocess.run([str(BINARY), "discount", str(price), str(employee)], cwd=ROOT,
                       capture_output=True, text=True, timeout=10)
    try:
        d = json.loads(r.stdout)
    except ValueError:
        raise RuntimeError("The Lean discount evaluator returned no valid result.") from None
    if r.returncode:
        raise Rejected(d.get("error", "Invalid discount case."))
    return d


class Handler(BaseHTTPRequestHandler):
    def send(self, status, data, content="application/json", cors=False):
        body = data if isinstance(data, bytes) else json.dumps(data).encode()
        self.send_response(status)
        self.send_header("Content-Type", content)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        if cors:  # read-only, loopback-only endpoint; lets the file:// demo page reach native Lean
            self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        url = urlsplit(self.path)
        if url.path in {"/demo", "/demo/", "/demo/index.html"}:
            self.send(200, (ROOT / "demo/index.html").read_bytes(), "text/html; charset=utf-8")
            return
        if url.path == "/api/ptc":
            try:
                q = parse_qs(url.query, keep_blank_values=True, max_num_fields=2)
                if set(q) != {"income"} or len(q["income"]) != 1:
                    raise Rejected("Provide one income field.")
                i = q["income"][0]
                if not i.isascii() or not i.isdigit() or len(i) > 6:
                    raise Rejected("Annual MAGI must be a small nonnegative whole-dollar integer.")
                self.send(200, ptc(int(i)), cors=True)
            except ValueError as e:
                self.send(400, {"error": str(e), "errorKind": "input"}, cors=True)
            except (OSError, RuntimeError, subprocess.TimeoutExpired):
                self.send(503, {"error": "The Lean PTC evaluator is unavailable."}, cors=True)
            return
        if url.path == "/api/interdomain":
            if url.query:
                self.send(400, {"error": "The inter-domain search accepts no query fields.", "errorKind": "input"})
                return
            try:
                self.send(200, interdomain())
            except (OSError, RuntimeError, subprocess.TimeoutExpired):
                self.send(503, {"error": "The Lean tax/healthcare evaluator is unavailable."})
            return
        if url.path == "/":
            self.send(200, (ROOT / "web/index.html").read_bytes(), "text/html; charset=utf-8")
            return
        if url.path == "/api/ai":
            self.send(200, AI.status())
            return
        if url.path == "/api/sources":
            self.send(200, {"leanContracts": (ROOT / "vendor/LeanContracts/Basic.lean").read_text(),
                "catala": (ROOT / "vendor/catala/section_132.catala_en").read_text(),
                "proof": (ROOT / "TaxGame/Verify.lean").read_text(),
                "repoProof": (ROOT / "TaxGame/Repos.lean").read_text(),
                "interdomainProof": (ROOT / "TaxGame/Interdomain.lean").read_text()})
            return
        if url.path == "/api/discount":
            try:
                q = parse_qs(url.query, keep_blank_values=True, max_num_fields=3)
                if set(q) != {"price", "employee"} or any(len(v) != 1 for v in q.values()):
                    raise Rejected("Provide one customer price and one employee price.")
                p, e = q["price"][0], q["employee"][0]
                if not p.isascii() or not e.isascii() or not p.isdigit() or not e.isdigit() or len(p) > 6 or len(e) > 6:
                    raise Rejected("Prices must be small nonnegative whole-dollar integers.")
                self.send(200, discount(int(p), int(e)))
            except ValueError as e:
                self.send(400, {"error": str(e), "errorKind": "input"})
            except (OSError, RuntimeError, subprocess.TimeoutExpired):
                self.send(503, {"error": "The Lean discount evaluator is unavailable."})
            return
        if url.path == "/api/audit":
            try:
                q = parse_qs(url.query, keep_blank_values=True, max_num_fields=2)
                if set(q) != {"kind"} or len(q["kind"]) != 1:
                    raise Rejected("Provide one audit kind.")
                self.send(200, audit(q["kind"][0]))
            except ValueError as e:
                self.send(400, {"error": str(e), "errorKind": "input"})
            except (OSError, RuntimeError, subprocess.TimeoutExpired):
                self.send(503, {"error": "The Lean audit engine is unavailable."})
            return
        if url.path != "/api/play":
            self.send(404, {"error": "Not found"})
            return
        try:
            if len(self.path) > 4096:
                raise Rejected("Request too long.")
            q = parse_qs(url.query, keep_blank_values=True, max_num_fields=5)
            if set(q) - {"policy", "wages", "side", "moves"} or any(len(v) != 1 for v in q.values()):
                raise Rejected("Only one policy, wages, side and moves field are accepted.")
            w, s = q.get("wages", ["1199"])[0], q.get("side", ["0"])[0]
            if not w.isascii() or not s.isascii() or not w.isdigit() or not s.isdigit():
                raise Rejected("Starting incomes must be nonnegative integers.")
            text = q.get("moves", [""])[0]
            self.send(200, engine(q.get("policy", ["old"])[0], int(w), int(s), text.split(",") if text else []))
        except ValueError as e:
            self.send(400, {"error": str(e), "errorKind": getattr(e, "kind", "input")})
        except (OSError, RuntimeError, subprocess.TimeoutExpired):
            self.send(503, {"error": "Lean engine unavailable. Retry after rebuilding."})

    def do_POST(self):
        if urlsplit(self.path).path != "/api/attack":
            self.send(404, {"error": "Not found"})
            return
        try:
            origin = self.headers.get("Origin")
            if origin and origin not in {f"http://127.0.0.1:{self.server.server_port}", f"http://localhost:{self.server.server_port}"}:
                raise ValueError("Start an attack from the local demo.")
            n = int(self.headers.get("Content-Length", "0"))
            if self.headers.get_content_type() != "application/json" or not 0 < n <= 128:
                raise ValueError("Provide a small JSON policy request.")
            d = json.loads(self.rfile.read(n))
            if not isinstance(d, dict) or set(d) != {"policy"} or not isinstance(d["policy"], str):
                raise ValueError("Provide only policy old or fixed.")
            self.send(200, AI.run(d["policy"], engine))
        except ValueError as e:
            self.send(400, {"error": str(e)})
        except (RuntimeError, OSError, subprocess.TimeoutExpired) as e:
            self.send(502, {"error": str(e)})

    def log_message(self, *args):
        pass


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8768)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--ai-check", choices=["old", "fixed"])
    args = parser.parse_args()
    subprocess.run(["lake", "build"], cwd=ROOT, check=True)
    if args.check:
        subprocess.run(["python3", "-m", "unittest", "discover", "-s", "tests", "-v"], cwd=ROOT, check=True)
    elif args.ai_check:
        result = AI.run(args.ai_check, engine)
        print(json.dumps({"model": result["model"], "attempts": [dict(title=p["title"], old=p["old"]["violations"], fixed=p["fixed"]["violations"]) for p in result["attempts"]]}, indent=2))
    else:
        server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
        print(f"The $1 Raise: http://127.0.0.1:{args.port}", flush=True)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass
        finally:
            server.server_close()

if __name__ == "__main__":
    main()
