# Glossary — fault-analysis acronyms by era paradigm

> Source of truth: `glossary.json`. Tooltips in the `.md.html` / `site/` renders
> come from the same file (`tools/gloss.py`). Run `python3 tools/gloss.py` to
> regenerate this page. Each term links to a definition.

## Era 1 — Reliability

| acronym | term | gloss |
|---|---|---|
| [FMEA](https://en.wikipedia.org/wiki/Failure_mode_and_effects_analysis) | Failure Mode and Effects Analysis | Bottom-up reliability method (1949): enumerate how each component can fail and the effects. Blind to interactions, software, humans. |

## Era 2 — System Safety

| acronym | term | gloss |
|---|---|---|
| [FTA](https://en.wikipedia.org/wiki/Fault_tree_analysis) | Fault Tree Analysis | Top-down Boolean failure logic (1962, Minuteman): trace a top event down to combinations of component failures. Good for redundancy; blind to non-failure causes. |
| [HAZOP](https://en.wikipedia.org/wiki/Hazard_and_operability_study) | Hazard and Operability Study | Guideword-driven process-deviation review (ICI, ~1970): systematically prompt 'no/more/less/reverse…' over a design. Process industries. |
| [MIL-STD-882](https://en.wikipedia.org/wiki/United_States_Military_Standard) | MIL-STD-882 (System Safety) | US DoD System Safety standard (1969–): the system-safety program-requirements lineage. |

## Era 3 — Probabilistic Risk

| acronym | term | gloss |
|---|---|---|
| [NAT](https://en.wikipedia.org/wiki/Normal_Accidents) | Normal Accident Theory | Perrow (1984): interactive complexity × tight coupling makes some accidents inevitable even when every part works. |
| [PRA](https://en.wikipedia.org/wiki/Probabilistic_risk_assessment) | Probabilistic Risk Assessment | Quantify risk via event trees × fault trees (WASH-1400, 1975). Ranks risks for regulators; blind to organizational drift and software. |
| [PSA](https://en.wikipedia.org/wiki/Probabilistic_risk_assessment) | Probabilistic Safety Assessment | Synonym for PRA, common in nuclear/European usage. |
| [SRK](https://en.wikipedia.org/wiki/Jens_Rasmussen_(human_factors_expert)) | Skills–Rules–Knowledge | Rasmussen's model of human performance levels (1983); basis for reasoning about operator error. |
| [WASH-1400](https://en.wikipedia.org/wiki/WASH-1400) | Reactor Safety Study (WASH-1400) | Rasmussen report (1975) that founded probabilistic risk assessment for nuclear plants. |

## Era 4 — Organizational

| acronym | term | gloss |
|---|---|---|
| [AcciMap](https://en.wikipedia.org/wiki/Jens_Rasmussen_(human_factors_expert)) | AcciMap | Rasmussen (1997): map causes of an accident across levels from government to work, following the socio-technical control hierarchy. |
| [CAST](https://en.wikipedia.org/wiki/Nancy_Leveson) | Causal Analysis based on System Theory | Accident-analysis counterpart to STPA: explain an accident as a loss of control across the hierarchy. In FM terms, a counterexample trace. |
| [HRO](https://en.wikipedia.org/wiki/High_reliability_organization) | High Reliability Organization | Weick & Sutcliffe et al.: organizations that stay safe in hazardous domains through mindfulness and practices. The optimistic counterpart to NAT. |
| [STAMP](https://en.wikipedia.org/wiki/Nancy_Leveson) | Systems-Theoretic Accident Model and Processes | Leveson (2004): accidents as inadequate control, not failure chains. Parent model of STPA and CAST. |
| [STPA](https://en.wikipedia.org/wiki/Nancy_Leveson) | Systems-Theoretic Process Analysis | Hazard-analysis method on STAMP: model the control structure, find unsafe control actions, derive safety constraints. Works for software, humans, interactions, early design. |

## Era 5 — Resilience

| acronym | term | gloss |
|---|---|---|
| [FRAM](https://en.wikipedia.org/wiki/Erik_Hollnagel) | Functional Resonance Analysis Method | Hollnagel (2004): model everyday performance variability and how it 'resonates' into failure. Studies what goes right; hard to falsify. |
| [Safety-I](https://en.wikipedia.org/wiki/Resilience_engineering) | Safety-I | Traditional view: safety = absence of accidents; study what goes wrong. Contrasted with Safety-II. |
| [Safety-II](https://en.wikipedia.org/wiki/Resilience_engineering) | Safety-II | Hollnagel: safety = ability to succeed under varying conditions; study what goes right. Leveson's Safety-III rebuts it. |

## Era 5 — Resilience / certification

| acronym | term | gloss |
|---|---|---|
| [GSN](https://en.wikipedia.org/wiki/Goal_structuring_notation) | Goal Structuring Notation | Graphical notation for assurance/safety cases: claims supported by arguments and evidence. Critiqued by Leveson. |

## Era certification

| acronym | term | gloss |
|---|---|---|
| [DO-178C](https://en.wikipedia.org/wiki/DO-178C) | DO-178C | Software Considerations in Airborne Systems and Equipment Certification — the airborne-software assurance standard. |
| [DO-333](https://en.wikipedia.org/wiki/DO-178C) | DO-333 (Formal Methods Supplement) | Supplement to DO-178C (2011) spelling out how formal methods count as certification evidence. |
| [IEC 61508](https://en.wikipedia.org/wiki/IEC_61508) | IEC 61508 | Functional safety of electrical/electronic/programmable safety-related systems; parent of many domain standards. |
| [ISO 26262](https://en.wikipedia.org/wiki/ISO_26262) | ISO 26262 | Functional safety standard for road vehicles (derived from IEC 61508). |

## Era formal methods

| acronym | term | gloss |
|---|---|---|
| [LTL](https://en.wikipedia.org/wiki/Linear_temporal_logic) | Linear Temporal Logic | Logic over time used to state safety/liveness properties; STPA constraints translate to LTL for model checking. |
| [PVS](https://en.wikipedia.org/wiki/Prototype_Verification_System) | Prototype Verification System | SRI's theorem prover used in certification-grade proofs (e.g., Darlington nuclear shutdown). |
| [TLA+](https://en.wikipedia.org/wiki/TLA%2B) | Temporal Logic of Actions (TLA+) | Lamport's specification language for concurrent/distributed systems; used by AWS to state 'what must go right'. |
