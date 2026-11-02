# Maya’s $1 raise: the 60-second story

**The setup:** Maya is 40, single, and buys a benchmark Silver plan through the Texas Marketplace. Her projected annual MAGI is $62,600. She is offered a $1 raise. The real 2026 PTC cutoff is 400% FPL; the example is representative, not a personal plan quote.

1. **Ask the question.** At $62,600, Maya receives a modeled $141 monthly federal tax credit and pays $520/month toward the $661 benchmark premium. Ask the room: *Would you take the $1 raise?*
2. **Reveal the consequence.** Maya accepts. Her MAGI becomes $62,601—just over the cutoff. Her $141 monthly credit ends. The same benchmark plan now costs $661/month, $1,692 more over a year. After the extra $1 of income, she has $1,691 less for the year before other taxes and expenses.
3. **Change the policy.** A proposed gradual phase-out keeps the credit at the boundary, then tapers it over the next $7,825 of income. The same raise leaves Maya's monthly premium at $520. The interface labels this as a hypothetical repair, not current law.
4. **Show what Lean checks.** `TaxGame.Interdomain.real_cutoff_cliff` proves the exact boundary calculation. `current_credit_zero_above_cutoff` proves the modeled credit is zero above the cutoff. `proposed_boundary_continuous` checks the repair has no sudden jump at this boundary. Lean generates the amounts and the graph points from the model.

The graph labels its axes: X is annual household MAGI; Y is monthly benchmark-plan premium after the federal credit. The exact-source drawer explains IRS rules, contribution rounding, KFF premium data, assumptions, and exclusions. The cliff is documented in current IRS rules; this demo did not discover it.

**Limits:** A person's actual benchmark premium is county- and age-specific. PTC qualification also depends on Marketplace enrollment and other coverage/filing conditions. This model excludes ordinary income and payroll taxes, state aid, cost sharing, changes in household circumstances, and tax-return reconciliation. The hypothetical taper is a policy experiment only. Lean proves the specified arithmetic, not individual eligibility or legal compliance.

The original fictional housing/work-support sandbox and the Catala employee-discount example remain available under **Explore more** and the **Employee discount** tab.
