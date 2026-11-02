#!/usr/bin/env python3
"""Log-scale SVG plots of abc / abc-1 trajectories. Data comes from `lake exe abc traj`,
i.e. from the proven `step` — this script never re-implements the rules. Stdlib only.
Usage: python3 plots/plot.py          (writes plots/*.svg and plots/index.md)"""
import subprocess, math, csv, io, os, sys
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.dirname(HERE)

def traj(variant, play, start):
    out = subprocess.run(["lake", "exe", "abc", "traj", variant, play, start], cwd=ROOT, capture_output=True, text=True, check=True).stdout
    rows = list(csv.DictReader(io.StringIO(out)))
    return [(int(r["t"]), int(r["a"]), int(r["b"]), int(r["c"]), int(r["score"]), r["alive"] == "1") for r in rows]

def symlog(x):  # sign(x)·log2(1+|x|): log scale that survives abc-1's negatives
    return math.copysign(math.log2(1 + abs(x)), x)

def svg(title, series, path, note=""):
    W, H, L, B, T, R = 720, 360, 60, 40, 50, 20
    pts = [(t, symlog(v)) for s in series for (t, v) in s["pts"]]
    tmax = max(t for t, _ in pts); ymin = min(min(y for _, y in pts), 0) - 0.3; ymax = max(y for _, y in pts) + 0.3
    X = lambda t: L + (W - L - R) * t / max(tmax, 1)
    Y = lambda y: T + (H - T - B) * (ymax - y) / (ymax - ymin)
    o = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" font-family="monospace" font-size="12">',
         f'<rect width="{W}" height="{H}" fill="white"/>', f'<text x="{L}" y="20" font-size="14" font-weight="bold">{title}</text>',
         f'<text x="{L}" y="36" fill="#555">{note}</text>']
    # y gridlines at powers of two (and negatives)
    span = ymax - ymin
    stepk = 1 if span < 14 else (3 if span < 30 else 5)
    for k in [j for j in range(-48, 49, stepk)] + ([0] if stepk > 1 else []):
        val = (2**abs(k) - 1) * (1 if k >= 0 else -1)
        y = symlog(val)
        if ymin <= y <= ymax:
            o.append(f'<line x1="{L}" x2="{W-R}" y1="{Y(y)}" y2="{Y(y)}" stroke="#eee"/>')
            o.append(f'<text x="{L-6}" y="{Y(y)+4}" text-anchor="end" fill="#666">{(f'{val:.0e}' if abs(val) >= 1e5 else val)}</text>')
    o.append(f'<line x1="{L}" x2="{W-R}" y1="{Y(0)}" y2="{Y(0)}" stroke="#999"/>')
    for t in range(0, tmax + 1, max(1, tmax // 12)):
        o.append(f'<text x="{X(t)}" y="{H-B+16}" text-anchor="middle" fill="#666">{t}</text>')
    o.append(f'<text x="{(L+W-R)/2}" y="{H-8}" text-anchor="middle" fill="#666">turn</text>')
    o.append(f'<text x="14" y="{(T+H-B)/2}" transform="rotate(-90 14 {(T+H-B)/2})" text-anchor="middle" fill="#666">value (symlog)</text>')
    for s in series:
        d = " ".join(f'{"M" if i == 0 else "L"}{X(t):.1f},{Y(symlog(v)):.1f}' for i, (t, v) in enumerate(s["pts"]))
        o.append(f'<path d="{d}" fill="none" stroke="{s["color"]}" stroke-width="{s.get("w", 2)}" stroke-dasharray="{s.get("dash", "")}"/>')
        t, v = s["pts"][-1]; o.append(f'<text x="{X(t)+4}" y="{Y(symlog(v))+4}" fill="{s["color"]}">{s["label"]}</text>')
    o.append("</svg>"); open(path, "w").write("\n".join(o))

COL = {"a": "#d62728", "b": "#1f77b4", "c": "#2ca02c"}
def abc_series(variant, play, start, dash=""):
    tr = traj(variant, play, start)
    return [{"label": k, "color": COL[k], "dash": dash, "pts": [(r[0], r[i]) for r in tr]} for i, k in ((1, "a"), (2, "b"), (3, "c"))], tr

figs = [
  ("grow", "abc", "cbaabcacb" * 3, "4,4,4", "(4,4,4): the proven `grow` line ×3 — all three climb (theorem unbounded4)"),
  ("greedy", "abc", "a" * 12, "4,4,4", "(4,4,4): click `a` only — a explodes, b and c die at turn 4 (0 is forever)"),
  ("trapped", "abc", "abc" + "cba" * 5, "3,3,3", "(3,3,3): survive forever in the 3-cycle, but min ≤ 3 always (theorem trapped3)"),
  ("doomed", "abc", "abcabc", "2,2,2", "(2,2,2): any play has a zero by turn 2 (theorem doomed2)"),
  ("doomed-nosat", "abc-1", "abcabc", "2,2,2", "abc-1 from (2,2,2): same play — negatives double downward"),
  ("greedy-nosat", "abc-1", "a" * 12, "4,4,4", "abc-1: click `a` only — b, c sink linearly (no floor); a identical to abc"),
  ("prod-spam35", "abc-1", "a" * 35, "1,1,1", "abc-1 product objective, N=35: spam `a` — product 2^35·34·34 ≈ 3.97e13 (proven optimal at N=9; witness at 35)"),
  ("prod-split35", "abc-1", "a" * 12 + "b" * 11 + "c" * 12, "1,1,1", "abc-1 N=35: double a, then b, then c — balanced magnitudes, product 8.27e12 (4.8× worse)"),
  ("prod-balanced", "abc", "cbaabcabcabc", "4,4,4", "abc product objective: the proven-optimal rotation ends at (18,19,20) — consecutive = balanced"),
]
PROD = {"prod-spam35", "prod-split35", "prod-balanced"}
os.makedirs(HERE, exist_ok=True); idx = ["# plots — trajectories from the proven `step`\n"]
for name, variant, play, start, note in figs:
    series, tr = abc_series(variant, play, start)
    if name in PROD:
        series.append({"label": "a·b·c", "color": "#111", "w": 3, "dash": "6,3", "pts": [(r[0], r[1]*r[2]*r[3]) for r in tr]})
    svg(f"{variant} from ({start})  play={play[:24]}{'…' if len(play) > 24 else ''}", series, os.path.join(HERE, f"{name}.svg"), note)
    last = tr[-1]; idx.append(f"## {name}\n{note}\n\n![{name}]({name}.svg)\n\nfinal: a={last[1]} b={last[2]} c={last[3]} min={last[4]}\n")
# par-vs-N curve for start 3,4,5 (oracle), both variants
open(os.path.join(HERE, "index.md"), "w").write("\n".join(idx))
# HTML gallery: all SVGs on one page, click to enlarge, embeddable (?embed=1)
cards = "".join(f'<figure><a href="{n}.svg" target="_blank"><img src="{n}.svg" alt="{n}"></a><figcaption><b>{n}</b> — {note}</figcaption></figure>' for n, _, _, _, note in figs)
open(os.path.join(HERE, "index.html"), "w").write(f"""<!doctype html><meta charset=utf-8><title>abc plots</title>
<style>body{{font:14px system-ui;margin:1rem;color:#222}}h1{{font-size:1.1rem}}.g{{display:grid;grid-template-columns:repeat(auto-fill,minmax(360px,1fr));gap:1rem}}
figure{{margin:0;border:1px solid #e3e3e3;border-radius:6px;padding:.4rem}}img{{width:100%;height:auto}}figcaption{{font-size:12.5px;color:#555;margin-top:.3rem}}
body.embed h1{{display:none}}</style><body><h1>abc / abc-1 — trajectories from the proven <code>step</code> (symlog axis) · <a href="../demo/index.html">demo</a> · <a href="../README.md">README</a></h1>
<div class=g>{cards}</div><script>if(location.search.includes('embed=1'))document.body.classList.add('embed')</script>""")
print("wrote", len(figs), "svgs + index.html")
