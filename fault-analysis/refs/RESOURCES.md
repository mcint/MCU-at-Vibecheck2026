# Safety & Engineering of Critical Systems — Resource Map
*Assembled 2026-11-01 for Loren. Companion to the earlier UI-verification / STPA→LTL bibliography from the Vibe Check hackathon thread.*

Organizing thesis (read this first, argue with it later):

> Safety engineering's ethos has moved from **"find the broken part"** (reliability, component failure) → **"find the unsafe interaction"** (system safety, hazards as control problems) → **"find the drift"** (sociotechnical migration toward the boundary). Each shift was forced by accidents whose parts all worked as designed. Formal methods ran a parallel track from **"find a counterexample"** (model checking, testing) to **"prove a bound"** (invariants, refinement), and the two tracks meet at exactly the question you're circling: *which few properties are worth proving?*

---

## 0. The ethos arc, era by era

Each era: what forced it, what it believed, what tools it minted, where to read.

### Era 0 — "Written in blood" (1800s–1930s): codes, inspection, insurance
- **Forcing events:** steamboat boiler explosions (US, 1816–1850s), railway disasters, Triangle Shirtwaist fire (1911).
- **Ethos:** safety = *rules distilled from past deaths*, enforced by inspection and liability. Retrospective, prescriptive.
- **Minted:** ASME Boiler & Pressure Vessel Code (1915), factory inspection regimes, **Heinrich's domino model** and the 300:29:1 pyramid (*Industrial Accident Prevention*, 1931) — the first *causal model*, still haunting us.
- **Read:** Henry Petroski, *To Engineer Is Human* (1985) and *Design Paradigms* (1994) — failure as the engine of design evolution. (Direct feed for your [[codes-in-blood]] theme.)

### Era 1 — Reliability (1940s–50s): the part is the problem
- **Forcing:** V-2 (Lusser's law: series reliability is the product of component reliabilities), WWII avionics, vacuum tubes.
- **Ethos:** accidents = component failures; make parts fail less, add redundancy.
- **Minted:** reliability engineering, **FMEA** (MIL-P-1629, 1949), MIL-HDBK-217 failure-rate handbooks.
- **Why it matters:** this is the paradigm Leveson spends a career arguing *out of*. "Safety is a different property than reliability" is the hinge of her whole program.

### Era 2 — System Safety (1960s): "first-time safe"
- **Forcing:** Minuteman ICBM — you cannot fly-fix-fly a nuclear missile; silo accidents; Atlas/Centaur pad explosions.
- **Ethos:** *hazards*, not failures, are the unit of analysis; safety must be **designed in**, not inspected in; safety is a property of the system, not components.
- **Minted:** **Fault Tree Analysis** (Bell Labs/Boeing for Minuteman, 1962), **MIL-STD-882** "System Safety Program Requirements" (1969; lineage from BSD Exhibit 62-41 → MIL-S-38130 → 882). **HAZOP** at ICI (Trevor Kletz, late 1960s/70s).
- **Read:**
  - NASA APPEL, [System Safety history and definition](https://appel.nasa.gov/?p=320373) — short, authoritative origin story.
  - C.O. Miller, [Concerns About the Practice of System Safety](https://jsystemsafety.com/blog/?p=236) (1993) — a founder complaining the field is collapsing into "hazard analysis exercises." Useful for seeing the ethos as *contested*, not just evolving.
  - Trevor Kletz, *What Went Wrong?* and *An Engineer's View of Human Error* — process-industry ethos: inherently safer design ("what you don't have can't leak").
  - MIL-STD-882E (current revision, DoD).

### Era 3 — Probabilistic Risk + Human Error (1970s–80s): the operator in the loop
- **Forcing:** **Three Mile Island** (1979), Bhopal (1984), Chernobyl (1986), Challenger (1986), Piper Alpha (1988), **Therac-25** (1985–87).
- **Ethos:** quantify risk; model the human; "human error" becomes a research object, then becomes suspect as an explanation.
- **Minted:** **WASH-1400** Reactor Safety Study (1975, Norman Rasmussen — PRA/PSA is born), *Fault Tree Handbook* NUREG-0492 (1981), **Jens Rasmussen's SRK** model (skills–rules–knowledge, 1983), **James Reason's** *Human Error* (1990) → Swiss cheese; **safety cases** (UK offshore after the Cullen Report on Piper Alpha, 1990).
- **The pivot text:** Charles Perrow, *Normal Accidents* (1984) — **interactive complexity × tight coupling** ⇒ some accidents are *normal*: parts working correctly, combining unpredictably. This is the first canonical statement of your "unexpected intersection of correctly working pieces."
- **Software enters:** Leveson & Turner, [An Investigation of the Therac-25 Accidents](https://www.se.rit.edu/~swen-342/resources/Leveson,%20Turner%20-%20An%20Investigation%20of%20the%20Therac-25%20Accidents%20-%20IEEE%20Computer%20v26n7%20-%201993-07.pdf) (IEEE Computer 1993) — the founding document of software safety as a discipline. Parnas, "Software Aspects of Strategic Defense Systems" (CACM 1985) — the first serious "software cannot be made trustworthy enough for this" argument.

### Era 4 — Organizational & sociotechnical (1990s–2000s): drift, culture, control
- **Forcing:** Challenger re-read (Vaughan), **Columbia** (2003), Überlingen (2002), Mars Climate Orbiter/Polar Lander (1999), Black Hawk friendly fire (1994).
- **Ethos:** accidents are *produced by normal organizational life*; safety is a **control problem** across a hierarchy from regulators to operators; systems *migrate* toward the boundary of acceptable performance under efficiency pressure.
- **Minted:**
  - **Rasmussen, [Risk Management in a Dynamic Society](https://backend.orbit.dtu.dk/ws/files/158016663/SAFESCI.pdf)** (Safety Science 1997) — the migration-to-boundary model and the multi-level control hierarchy. Arguably the single most generative paper in the field.
  - Diane Vaughan, *The Challenger Launch Decision* (1996) — **normalization of deviance**.
  - Reason, *Managing the Risks of Organizational Accidents* (1997); Weick & Sutcliffe, *Managing the Unexpected* (HRO theory); Scott Sagan, *The Limits of Safety* (1993) — NAT vs HRO on nuclear weapons.
  - **Leveson, STAMP** (2004) → [*Engineering a Safer World*](https://www.flighttestsafety.org/images/Engineering_a_Safer_World.pdf) (MIT Press 2011, open access; also on OAPEN) — accidents as *inadequate control*, not failure chains; **STPA** hazard analysis; **CAST** accident analysis.
  - Richard Cook, [How Complex Systems Fail](https://www.gwern.net/doc/technology/2000-cook.pdf) (1998) — 18 theses; the bridge document that carried all of this into web operations / SRE.
  - Leveson, Dulac, Marais, Carroll, "Moving Beyond Normal Accidents and High Reliability Organizations" (Organization Studies 2009) — the three-way debate in one place.
- **Accident reports that teach this era:** Columbia Accident Investigation Board report (2003, Vol. 1 esp. ch. 6–8 on organizational causes); Leveson, "The Role of Software in Spacecraft Accidents" (J. Spacecraft & Rockets 2004); Mars Climate Orbiter Mishap Investigation Board (1999).

### Era 5 — Resilience vs Systems (2006–present): the live argument
- **Forcing:** Deepwater Horizon (2010), Fukushima (2011), AF447 (2009), **Boeing 737 MAX** (2018–19), Knight Capital (2012), 2003 Northeast blackout — plus the "everything is software now" shift.
- **Two camps, worth reading as a dialectic:**
  - **Resilience Engineering / Safety-II:** Hollnagel, Woods, Leveson (eds.), *Resilience Engineering: Concepts and Precepts* (2006); Hollnagel, *Safety-I and Safety-II* (2014); FRAM; Dekker, *Drift into Failure* (2011) and *The Field Guide to Understanding 'Human Error'*; Woods' "graceful extensibility." Ethos: study *what goes right*; humans create safety continuously.
  - **Leveson's rebuttal:** [Safety-III: A Systems Approach to Safety and Resilience](https://psas.scripts.mit.edu/home/nancys-white-papers/) (2020, 109pp white paper) — argues Safety-I is a strawman, Safety-II was "rejected long ago in sophisticated engineering projects," and System Safety already *is* the resilient approach. Same page: her [critique of safety cases / GSN](https://psas.scripts.mit.edu/home/nancys-white-papers/) and "Are You Sure Your Software Will Not Kill Anyone?" (CACM 2020).
  - Terje Aven, "A risk science perspective on Safety I/II/III" (Safety Science 2022) — referee's view.
- **Newest synthesis:** Leveson, *An Introduction to System Safety Engineering* (MIT Press, Nov 2023, ~690pp) — textbook successor to *Safeware* (1995); ch. 1 is the history. (This is the big recent book you half-remembered; it's not ATC-specific — her ATC/aviation material is spread across STAMP case studies.)
- **Epistemic accidents:** John Downer, "Anatomy of a Disaster: Why Some Accidents Are Unavoidable" (2011) and *Rational Accidents* (MIT Press 2024) — accidents from *knowledge that was reasonable but wrong*; the sharpest recent take on "not predictable."

---

## 1. The "correctly working pieces, wrong combination" canon
Cases where the investigation found no broken part — only interaction. Ordered by how cleanly they make the point.

1. **Ariane 5 flight 501 (1996)** — reused Ariane 4 inertial software, correct to its original spec, overflowed on Ariane 5's trajectory. ESA/CNES Inquiry Board report. The purest "spec was right for the old system" case.
2. **Mars Climate Orbiter (1999)** — pound-force·seconds vs newton·seconds across a team interface; both teams' code was correct.
3. **Therac-25 (1985–87)** — race condition + removed hardware interlocks + reused Therac-20 code + operator speed. Leveson & Turner (above).
4. **Black Hawk shootdown, Iraq 1994** — IFF, AWACS, F-15 procedures each "worked"; Leveson's CAST analysis in *Engineering a Safer World* ch. 5.
5. **Überlingen mid-air (2002)** — TCAS and ATC gave contradictory, individually-correct instructions. BFU report.
6. **AF447 (2009)** — pitot icing → autopilot disconnect → alternate law; every subsystem behaved per design. BEA final report (2012). Also the canonical **mode confusion** case — ties to Sarter & Woods, "How in the World Did We Ever Get into That Mode?" (Human Factors 1995).
7. **Boeing 737 MAX / MCAS (2018–19)** — single-sensor authority + certification assumptions about pilot reaction time + training economics. House Transportation Committee Final Report (2020); JATR report (2019).
8. **2003 Northeast blackout** — alarm software silent-fail + reasonable operator inferences; US–Canada Task Force Final Report (2004).
9. **Knight Capital (2012)** — dead code reactivated by partial deploy; SEC order (2013). The software-ops case.
10. **Three Mile Island (1979)** — Perrow's ch. 1 is the definitive "normal accident" walk-through. Kemeny Commission report.
11. **Columbia (2003)** — foam strike was *known and normalized*; CAIB Vol. 1.

Grab bag: Peter Neumann, *Computer-Related Risks* (1995) and the ongoing [RISKS Digest](https://catless.ncl.ac.uk/Risks/); Lorin Hochstein's [resilience-engineering notes](https://github.com/lorin/resilience-engineering) (curated, software-leaning); [Learning From Incidents](https://www.learningfromincidents.io/) community.

---

## 2. Methods lineage (hazard analysis as a fossil record)

| Method | Born | Causal model it assumes | Good at | Blind to |
|---|---|---|---|---|
| FMEA | 1949 | single component failure | parts, bottom-up | interactions, software, humans |
| Fault Tree Analysis | 1962 | Boolean failure logic, top-down | redundancy design, quantification | non-failure causes, dynamics |
| HAZOP | ~1970 | process deviation (guidewords) | chemical plants, systematic prompting | design-intent errors |
| PRA / PSA | 1975 | event trees × fault trees | ranking risks, regulators | organizational drift, software |
| Bow-tie | 1990s | barriers around a top event | communication, offshore | same as FTA |
| AcciMap | 1997 | Rasmussen's multi-level hierarchy | accident analysis across society | prospective analysis |
| STPA / CAST | 2004– | control loops, unsafe control actions | software, humans, interactions, *early design* | quantification (by design) |
| FRAM | 2004– | functional resonance, variability | "what goes right," healthcare | it's hard to make falsifiable |

- **STPA Handbook** (Leveson & Thomas, 2018) — free from the [MIT PSAS site](https://psas.scripts.mit.edu/home/). The four-step method; your earlier STPA→LTL papers hang off this.
- Avizienis, Laprie, Randell, Landwehr, "Basic Concepts and Taxonomy of Dependable and Secure Computing" (IEEE TDSC 2004) — the vocabulary (fault/error/failure, safety vs reliability vs availability) everyone else borrows.

---

## 3. Formal methods for critical systems — the "prove a bound" tradition

### 3a. What "safety" means in each tradition (the hinge)
- **Lamport, "Proving the Correctness of Multiprocess Programs"** (IEEE TSE 1977) — defines **safety** ("nothing bad ever happens") vs **liveness** ("something good eventually happens"). Alpern & Schneider, "Defining Liveness" (1985) — every property is the intersection of a safety and a liveness property.
- **Schneider, "Enforceable Security Policies"** (ACM TISSEC 2000) — safety properties are exactly those a runtime monitor can enforce. This is why your "ratchet" is naturally a safety property: a monitor/proof can refuse the bad step.
- Translation table: safety-engineering *hazard* ≈ formal *bad state*; *safety constraint* ≈ *invariant*; *unsafe control action* ≈ *forbidden transition*; *CAST* ≈ *counterexample trace*.

### 3b. Certification-grade formal methods (the Rushby shelf)
- John Rushby, [Formal Methods and the Certification of Critical Systems](https://www.csl.sri.com/~rushby/papers/csl-93-7.pdf) (SRI/NASA/FAA 1993, ~300pp) — still the best single treatment of *why* and *where* formal methods pay off in safety-critical work; written for certifiers, not logicians. Companion: [Formal Methods and their Role in the Certification of Critical Systems](https://www.csl.sri.com/papers/csl-95-1) (1995, shorter).
- Rushby, [The Interpretation and Evaluation of Assurance Cases](https://www.csl.sri.com/~rushby/papers/sri-csl-15-1-assurance-cases.pdf) (2015) and [Assurance and Assurance Cases](https://www.csl.sri.com/~rushby/abstracts/marktoberdorf16) (2017) — how proof becomes *evidence* inside an argument; "indefeasible justification." Read against Leveson's GSN critique for the live disagreement.
- Rushby, [An Automated Method to Detect Potential Mode Confusions](https://www.csl.sri.com/~rushby/abstracts/dasc99) (1999) — model-check pilot mental model vs autopilot. (From the earlier bibliography; the AF447 bridge.)
- DO-178C + **DO-333** (formal methods supplement, 2011); IEC 61508; ISO 26262; EN 50128 (rail). The standards are the fossil record of what regulators would accept as evidence.
- Industrial landmarks: Paris Métro Line 14 (B method, 1998); **seL4** microkernel proof (Klein et al., SOSP 2009; [sel4.systems](https://sel4.systems/)); **CompCert** verified C compiler ([compcert.org](https://compcert.org/)); Airbus/Astrée abstract interpretation; Darlington nuclear shutdown software (Parnas, 1990s — see Rushby & Srivas, "Using PVS to Prove Some Theorems of David Parnas").

### 3c. Lightweight / "prove a few things that matter"
This is the lineage that answers your grandma question.
- **Jackson & Wing, "Lightweight Formal Methods"** (IEEE Computer, April 1996) — partiality in language, modeling, analysis, and composition: verify *one important thing*, not everything. Daniel Jackson, *Software Abstractions* (Alloy) — the **small-scope hypothesis**: most bugs have small counterexamples, so bounded search is enough. (This is the respectable version of "take your foot off the gas.")
- **Newcombe et al., [How Amazon Web Services Uses Formal Methods](https://lamport.azurewebsites.net/tla/formal-methods-amazon.pdf)** (CACM 2015) — the business-side ethos: start by precisely stating "what needs to go right"; TLA+ on S3/DynamoDB. Follow-up: Brooker & Desai, [Systems Correctness Practices at AWS](https://queue.acm.org/detail.cfm?id=3712057) (ACM Queue 2025) — the full ladder from property-based testing → P → TLA+ → deductive proof.
- **Hillel Wayne**, [The Business Case for Formal Methods](https://hillelwayne.com/post/business-case-formal-methods/), "Why Don't People Use Formal Methods?", "There Was No Formal Methods Winter" — and his line that most teams should adopt property-based testing and stop there.
- **UW CSEP 590B formal-methods library** ([courses.cs.washington.edu](https://courses.cs.washington.edu/courses/csep590b/26sp/library)) — a curated, tagged (cheerleader/critic/economics) reading list of the whole FM-adoption debate. Best single jumping-off page for this subsection.
- Classic dialectic: Anthony Hall, "Seven Myths of Formal Methods" (IEEE Software 1990); Bowen & Hinchey, "Seven More Myths" (1995); Woodcock et al., "Formal Methods: Practice and Experience" (ACM Computing Surveys 2009) — the big survey of industrial use.
- Lamport, *Specifying Systems* (free PDF) — ch. on invariants: the discipline of *finding the inductive invariant* is the discipline of deciding what's worth proving.

### 3d. Counterexample vs bound — the two mindsets as tools
- **Model checking** (Clarke, Emerson, Sifakis — Turing Award 2007): exhaustive *counterexample search*. SPIN, TLC, NuSMV, UPPAAL. Your security instinct lives here; it is not wrong, it is bounded.
- **Theorem proving** (Lean, Isabelle, Coq/Rocq, PVS): *bound-proving*; needs you to state the invariant. The cost is choosing; the payoff is for-all.
- **The honest middle:** bounded model checking, property-based testing (QuickCheck/Hypothesis), fuzzing, runtime verification — "prove a bound, up to depth k."

---

## 4. Communities, courses, living resources
- MIT **PSAS** (Partnership for Systems Approaches to Safety and Security) — annual STAMP workshop, free handbooks, white papers: [psas.scripts.mit.edu](https://psas.scripts.mit.edu/home/).
- **System Safety Society** and *Journal of System Safety* — the 1960s lineage, still alive: [jsystemsafety.com](https://jsystemsafety.com/).
- Resilience Engineering Association; **Learning From Incidents** (software) — [learningfromincidents.io](https://www.learningfromincidents.io/).
- SRI Formal Methods Program — Rushby's full bibliography: [csl.sri.com/~rushby](https://www.csl.sri.com/~rushby/).
- NASA Software Safety Guidebook (NASA-GB-8719.13); NASA Formal Methods Specification and Verification Guidebook (1995/97).
- Safety Science (journal), Reliability Engineering & System Safety, Journal of Loss Prevention — where the ethos arguments actually happen.

---

## 5. Three reading paths

**A. Ethos in a weekend (≈300 pages)**
Cook (5pp) → Rasmussen 1997 (30pp) → Perrow ch. 1–3 → Leveson *Safety-III* preface + "Does Safety-I exist?" + comparison chapter → Leveson & Turner Therac-25.

**B. From hazard to theorem (your ratchet)**
STPA Handbook ch. 1–2 → Lamport 1977 (safety/liveness) → Schneider 2000 → Jackson & Wing 1996 → Amazon CACM 2015 → the STPA→LTL papers from the earlier bibliography → write one invariant per unsafe control action.

**C. Certification mind**
Rushby 1993 ch. 1–2 → DO-333 overview → Rushby assurance cases 2015 ch. 1–3 → Leveson GSN critique → seL4 2009 paper.

---

## 6. Open questions worth chewing (for the OODA update)
1. Is "prove a bound" the *same* move as Rasmussen's "keep the system inside the envelope," just with a proof assistant instead of a regulator? If so, STPA's safety constraints are your invariant list and you're done choosing.
2. Perrow and Downer both say some accidents are *not predictable*. Does a proved invariant change that claim, or only move the unpredictability into the model's assumptions (Ariane 5 says: the latter)?
3. The grandma test, operationalized: a property is worth proving iff a CAST analysis of a plausible accident would cite its violation as a causal factor. That makes accident reports the *generator* for your property list.
