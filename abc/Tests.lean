import Abc
import Optimal
import Perturb
open Abc

-- rule sanity
#guard step .sat ⟨4,4,4⟩ .A = ⟨8,3,3⟩
#guard step .sat ⟨1,0,5⟩ .B = ⟨0,0,4⟩           -- 0·2 = 0, saturation
#guard step .nosat ⟨1,0,5⟩ .B = ⟨0,0,4⟩
#guard step .nosat ⟨0,-1,5⟩ .B = ⟨-1,-2,4⟩      -- negative doubles down, no floor
#guard step .sat ⟨0,-1,5⟩ .B = ⟨0,0,4⟩
-- variants agree while alive
#guard runFrom .sat s4 grow = runFrom .nosat s4 grow
-- ladder witnesses
#guard runFrom .sat s4 grow = ⟨10,10,13⟩
#guard runFrom .sat s3 [.A,.B,.C] = ⟨4,3,2⟩
#guard (traj .sat s3 (forever 3)).all alive
#guard hasZero (runFrom .sat s2 [.A,.B]) = true
#guard score (runFrom .sat s2 [.A,.A,.A,.A]) = 0
#guard score (runFrom .nosat s2 [.A,.A,.A,.A]) = -2
-- par (max-min) matches the Python exploration: start 4, N=9 → 10 ; start 3 → 2 ; start 5 → 18
#guard bestFrom .sat s4 9 = 10
#guard bestFrom .sat s3 9 = 2
#guard bestFrom .sat ⟨5,5,5⟩ 9 = 18
#guard bestFrom .nosat s4 9 = 10
-- oracle consistency
#guard score (runFrom .sat s4 (bestPlay .sat s4 7)) = bestFrom .sat s4 7
#guard F.length = 97
-- product objective
#guard prod ⟨2,-3,-5⟩ = 30
#guard bestProd .sat s4 6 = 336
#guard prod (runFrom .sat s4 (bestPlay .sat s4 6)) ≤ 336      -- min-oracle play is not product-optimal, bound still holds
#guard bestProd .nosat s1 9 = 32768
#guard prod (runFrom .nosat s1 split35) < prod (runFrom .nosat s1 spam35)
-- optimality at every horizon (Optimal.lean): bound N = 2^N (N−1)^2, spam attains it
#guard bound 9 = 32768
#guard bound 35 = 39719857553408
#guard prod (runFrom .nosat s1 split35) < bound 35
-- perturbations (Perturb.lean)
#guard best2 o2 6 = 8
#guard best2 o2 10 = 1024
#guard prod2 (run2 o2 (List.replicate 10 .A)) < 0
#guard bestSum .sat s4 9 = 2048
