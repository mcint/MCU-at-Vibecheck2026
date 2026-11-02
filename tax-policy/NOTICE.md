# Third-party source and scope

LeanContracts: https://github.com/tripp-smith/leancontracts, commit b9fc2e85897774decd01126f1b2e6a943adabd91, Copyright 2026 LeanContracts contributors, Apache-2.0. `vendor/LeanContracts/Basic.lean` and `Semantics.lean` are copied unmodified, with the upstream LICENSE. They compile and execute here. Only these two modules are reused; full upstream-package correctness and original-toolchain compatibility are not claimed.

Catala examples: https://github.com/CatalaLang/catala-examples, commit 9e251b932288cf5f4a74af072d203144a057494b, Apache-2.0. `vendor/catala/section_132.catala_en` and LICENSE.txt are copied unmodified. `TaxGame/Repos.lean` contains an attributed port of the displayed services-discount cap case; the source and port are distinguished in the interface. The Catala compiler is not executed. No endorsement by either upstream project is implied.

The main tax/benefit game, its numerical policies, proofs and interface are newly implemented for this demonstration. Its rules are fictional and are not copied from an actual jurisdiction. All external source remains under its own license.
