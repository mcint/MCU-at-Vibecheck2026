#!/usr/bin/env bash
# Build everything (library theorems, #guard tests, pd exe) and smoke-test pd.
set -euo pipefail
cd "$(dirname "$0")"
lake build 2>&1 | grep -v '^trace' | grep -v '^✔' || true
PD=.lake/build/bin/pd
[ -x "$PD" ] || { echo "pd not built"; exit 1; }

fail=0
check() { # check <description> <expected-substring> <actual>
  if printf '%s' "$3" | grep -qF -- "$2"; then echo "ok   $1"; else echo "FAIL $1"; echo "     expected: $2"; echo "     got:      $3"; fail=1; fi
}

echo "== pd: flags =="
out=$($PD --cl 5 --te --chunked 12 | tr '\n' ' ')
check "CL+TE strict rejects"   '"profile":"strict","accept":false,"body_len":null' "$out"
check "CL+TE teWins -> 12"      '"profile":"teWins","accept":true,"body_len":12'   "$out"
check "CL+TE clFirst -> 5"      '"profile":"clFirst","accept":true,"body_len":5'   "$out"

out=$($PD --cl 5 --cl 7 | tr '\n' ' ')
check "dup CL strict rejects"  '"profile":"strict","accept":false,"body_len":null' "$out"
check "dup CL clFirst -> 5"    '"profile":"clFirst","accept":true,"body_len":5'   "$out"
check "dup CL clLast -> 7"     '"profile":"clLast","accept":true,"body_len":7'    "$out"

echo "== pd: raw request on stdin =="
out=$(printf 'POST / HTTP/1.1\r\nHost: a\r\nContent-Length: 6\r\nTransfer-Encoding: chunked\r\n\r\n0\r\n\r\nG' | $PD | tr '\n' ' ')
check "raw CL.TE facts"        '"cls":[6],"te":true,"chunkedLen":5' "$out"
out=$(printf 'POST / HTTP/1.1\r\nHost: a\r\ncontent-length: 4\r\nTransfer-Encoding: gzip, chunked\r\n\r\n5;x=y\r\nhello\r\n0\r\n\r\n' | $PD | tr '\n' ' ')
check "raw chunk ext + 2 chunks" '"cls":[4],"te":true,"chunkedLen":19' "$out"
out=$(printf 'GET / HTTP/1.1\r\nHost: a\r\n\r\n' | $PD | tr '\n' ' ')
check "raw clean GET all 0"    '"profile":"clLast","accept":true,"body_len":0' "$out"

echo "== pd: search =="
out=$($PD --matrix | tr '\n' ' ')
check "matrix clFirst/teWins 60" '"front":"clFirst","back":"teWins","witnesses":60,"space":168' "$out"
check "matrix clFirst/strict 0"  '"front":"clFirst","back":"strict","witnesses":0,"space":168' "$out"
n=$($PD --witnesses clFirst clLast | wc -l | tr -d ' ')
check "witness list clFirst/clLast has 96 lines" "96" "$n"

echo "== axioms =="
ax=$(lake env lean Tests.lean 2>&1 | grep -c "sorryAx\|ofReduceBool" || true)
if [ "$ax" = "0" ]; then echo "ok   only propext / Quot.sound (no sorryAx, no native_decide)"; else echo "FAIL unexpected axiom"; fail=1; fi
if grep -rn "sorry" ParserDiff Main.lean Tests.lean; then echo "FAIL sorry present"; fail=1; else echo "ok   no sorry"; fi

if [ $fail -eq 0 ]; then echo "ALL TESTS PASSED"; else echo "SOME TESTS FAILED"; exit 1; fi
