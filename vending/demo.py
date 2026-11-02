#!/usr/bin/env python3
"""Loopback-only UI. Lean owns parsing, transitions, replay, and game verdicts."""
from __future__ import annotations

import argparse
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import subprocess
from urllib.parse import parse_qs, urlsplit
from adversary import Experiment

ROOT = Path(__file__).resolve().parent
BINARY = ROOT / ".lake/build/bin/vending_game"
AI = Experiment(ROOT / "runs/ai-latest.json")
RUSH_AI = Experiment(ROOT / "runs/rush-ai-latest.json", scenario="rush")


def run_game(level: str, moves: str = "", *, binary: Path = BINARY, enforce_policy: bool = False,
             scenario: str = "solo") -> dict:
    if not isinstance(scenario, str) or scenario not in {"solo", "rush"}:
        raise ValueError("Choose solo or rush.")
    if level not in {"1", "2", "3", "4"}:
        raise ValueError("Choose a level from 1 to 4.")
    if len(moves) > 2048 or (moves and len(moves.split(",")) > 32):
        raise ValueError("The move history is too long.")
    command = "rush-policy" if scenario == "rush" else "play-policy" if enforce_policy else "play"
    result = subprocess.run(
        [str(binary), command, level, moves], cwd=ROOT,
        capture_output=True, text=True, timeout=10,
    )
    try:
        data = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise RuntimeError("The Lean engine returned an invalid response.") from exc
    if result.returncode:
        raise ValueError(data.get("error", "Lean rejected the move history."))
    return data


def play(level: str, moves: str = "") -> dict:
    return run_game(level, moves)


class Handler(BaseHTTPRequestHandler):
    page = ROOT / "web/index.html"

    def send(self, status: int, body: bytes, content_type: str) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        url = urlsplit(self.path)
        if url.path == "/":
            self.send(200, self.page.read_bytes(), "text/html; charset=utf-8")
            return
        if url.path == "/api/ai":
            args = parse_qs(url.query, keep_blank_values=True)
            if set(args) - {"scenario"} or any(len(v) != 1 for v in args.values()) or args.get("scenario", ["solo"])[0] not in {"solo", "rush"}:
                self.send(400, b'{"error":"Choose one scenario: solo or rush."}', "application/json")
                return
            experiment = RUSH_AI if args.get("scenario", ["solo"])[0] == "rush" else AI
            self.send(200, json.dumps(experiment.status()).encode(), "application/json")
            return
        if url.path != "/api/play":
            self.send(404, b"Not found", "text/plain")
            return
        try:
            if len(self.path) > 4096:
                raise ValueError("The request is too long.")
            args = parse_qs(url.query, keep_blank_values=True, max_num_fields=4)
            if set(args) - {"level", "moves", "scenario"} or any(len(v) != 1 for v in args.values()):
                raise ValueError("Only one level, moves, and scenario parameter are accepted.")
            data = run_game(args.get("level", ["1"])[0], args.get("moves", [""])[0],
                            enforce_policy=True, scenario=args.get("scenario", ["solo"])[0])
            self.send(200, json.dumps(data).encode(), "application/json")
        except ValueError as exc:
            self.send(400, json.dumps({"error": str(exc)}).encode(), "application/json")
        except (OSError, RuntimeError, subprocess.TimeoutExpired):
            self.send(503, b'{"error":"The Lean engine is unavailable. Retry after rebuilding."}', "application/json")

    def do_POST(self) -> None:
        if urlsplit(self.path).path != "/api/attack":
            self.send(404, b"Not found", "text/plain")
            return
        try:
            origin = self.headers.get("Origin")
            if origin and origin not in {f"http://127.0.0.1:{self.server.server_port}",
                                         f"http://localhost:{self.server.server_port}"}:
                raise ValueError("Use the local demo page to start an attack.")
            if self.headers.get_content_type() != "application/json":
                raise ValueError("The attack request must be JSON.")
            length = int(self.headers.get("Content-Length", "0"))
            if not 0 < length <= 256:
                raise ValueError("The attack request has an invalid size.")
            data = json.loads(self.rfile.read(length))
            if (not isinstance(data, dict) or set(data) not in ({"level"}, {"level", "scenario"})
                    or not isinstance(data.get("level"), str) or not isinstance(data.get("scenario", "solo"), str)
                    or data.get("scenario", "solo") not in {"solo", "rush"}):
                raise ValueError("Provide the policy level (3 or 4) and optional scenario (solo or rush).")
            scenario = data.get("scenario", "solo")
            experiment = RUSH_AI if scenario == "rush" else AI
            report = experiment.run(data["level"], lambda level, moves: run_game(level, moves, enforce_policy=True, scenario=scenario))
            self.send(200, json.dumps(report).encode(), "application/json")
        except ValueError as exc:
            self.send(400, json.dumps({"error": str(exc)}).encode(), "application/json")
        except RuntimeError as exc:
            self.send(502, json.dumps({"error": str(exc)}).encode(), "application/json")
        except (OSError, subprocess.TimeoutExpired):
            self.send(503, b'{"error":"The game engine is unavailable."}', "application/json")

    def log_message(self, format: str, *args) -> None:
        pass


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8766)
    parser.add_argument("--check", action="store_true", help="Build and run acceptance tests.")
    parser.add_argument("--ai-check", choices=["3", "4"], help="Make one bounded live Claude call and replay its plans against both policies.")
    parser.add_argument("--scenario", choices=["solo", "rush"], default="solo", help="Choose the AI-check round.")
    args = parser.parse_args()
    subprocess.run(["lake", "build"], cwd=ROOT, check=True)
    if args.ai_check:
        experiment = RUSH_AI if args.scenario == "rush" else AI
        report = experiment.run(args.ai_check, lambda level, moves: run_game(level, moves, enforce_policy=True, scenario=args.scenario))
        print(json.dumps({"model": report["model"], "attackedPolicy": report["attackedPolicy"],
                          "attempts": [{"title": a["title"], "moves": a["proposedMoves"],
                                        "oldExploit": a["old"]["exploitFound"],
                                        "repairedExploit": a["repaired"]["exploitFound"]}
                                       for a in report["attempts"]]}, indent=2))
        return
    if args.check:
        subprocess.run(["python3", "-m", "unittest", "discover", "-s", "tests", "-v"], cwd=ROOT, check=True)
        return
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    print(f"Play the rules: http://127.0.0.1:{server.server_port}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
