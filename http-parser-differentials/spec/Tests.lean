import ParserDiff

/-! Executable checks (`#guard`) plus the axiom audit. `lake build Tests` fails if any guard fails. -/

namespace ParserDiff
open Profile

-- clean messages: everyone agrees
#guard frame strict  ⟨[], false, 0⟩ = some 0
#guard frame clFirst ⟨[], false, 0⟩ = some 0
#guard frame strict  ⟨[5], false, 0⟩ = some 5
#guard frame strict  ⟨[5, 5], false, 0⟩ = some 5
#guard frame strict  ⟨[], true, 12⟩ = some 12
#guard Profile.all.all fun p => frame p ⟨[5, 5], false, 0⟩ == some 5
#guard Profile.all.all fun p => frame p ⟨[], true, 12⟩ == some 12

-- CL + TE (the CL.TE / TE.CL shape)
#guard frame strict  ⟨[5], true, 12⟩ = none
#guard frame teWins  ⟨[5], true, 12⟩ = some 12
#guard frame clFirst ⟨[5], true, 12⟩ = some 5
#guard frame clLast  ⟨[5], true, 12⟩ = some 5
#guard desyncB clFirst teWins ⟨[5], true, 12⟩
#guard desyncB teWins clFirst ⟨[5], true, 12⟩
#guard !desyncB clFirst strict ⟨[5], true, 12⟩   -- strict rejects: safe
#guard !desyncB strict teWins ⟨[5], true, 12⟩

-- duplicate differing Content-Length
#guard frame strict  ⟨[5, 7], false, 0⟩ = none
#guard frame teWins  ⟨[5, 7], false, 0⟩ = none
#guard frame clFirst ⟨[5, 7], false, 0⟩ = some 5
#guard frame clLast  ⟨[5, 7], false, 0⟩ = some 7
#guard desyncB clFirst clLast ⟨[5, 7], false, 0⟩
#guard !desyncB clFirst teWins ⟨[5, 7], false, 0⟩  -- teWins rejects: safe

-- search space facts
#guard space.length = 168
#guard (witnesses clFirst teWins).length = 60
#guard (witnesses clFirst clLast).length = 96
#guard (witnesses strict teWins).length = 0
#guard Profile.all.all fun F => (witnesses F strict).isEmpty
#guard Profile.all.all fun B => (witnesses strict B).isEmpty
#guard (witnesses clFirst teWins).all fun m => m.te && !m.cls.isEmpty
#guard witnesses clFirst teWins |>.contains ⟨[1], true, 2⟩

-- readings sanity
#guard readings ⟨[5], true, 12⟩ = [12, 5]
#guard readings ⟨[], false, 0⟩ = [0]

#print axioms strict_unambiguous
#print axioms no_desync_strict_strict
#print axioms backend_strict_safe
#print axioms frontend_strict_safe
#print axioms refines_no_desync
#print axioms strict_bottom
#print axioms desync_only_on_dirty
#print axioms desync_clFirst_teWins_iff
#print axioms desync_clFirst_clLast_iff
#print axioms witness_clFirst_teWins
#print axioms witness_clFirst_clLast
#print axioms no_witness_backend_strict
#print axioms dirty_of_anyDesync
#print axioms refines_strict_iff

end ParserDiff
