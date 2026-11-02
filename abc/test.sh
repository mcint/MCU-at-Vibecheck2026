#!/usr/bin/env bash
set -e; cd "$(dirname "$0")"
lake build 2>&1 | grep -E "^error|sorry" && exit 1
out=$(printf 'c\nb\na\nu\nu\n?\n!\nr\nr\nq\n' | lake exe abc abc 9)
for want in "turn 3/9  a=4 b=5 c=6  min=4  alive" "turn 1/9" "oracle: best reachable min from here = 10" "oracle: a best line" "peeks=2" "bye"; do
  grep -qF "$want" <<<"$out" || { echo "MISSING: $want"; echo "$out"; exit 1; }; done
out2=$(printf 'a\na\na\nq\n' | lake exe abc abc 4 2,2,2); grep -qF "DEAD" <<<"$out2" || { echo "MISSING DEAD"; exit 1; }
out3=$(printf 'a\na\na\nq\n' | lake exe abc abc-1 4 2,2,2); grep -qF "SINKING" <<<"$out3" || { echo "MISSING SINKING"; exit 1; }
lake exe abc traj abc cbaabcacb 4,4,4 | grep -qF "9,10,10,13,10,1" || { echo "traj wrong"; exit 1; }
echo "ALL TESTS PASSED"
