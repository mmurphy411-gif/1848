# Milestone 12 — the salmon run

Implement visible, finite daily salmon takes with a purchased spear; dawn bear occupation, a contextual shout, and night raids on exposed animal food. Hanging-cache food is protected. Sleeping resolves an unobserved raid once, so skipping the night cannot evade it. Shouting excludes that bear for the current day. The bear never attacks the miner.

Large fish are portioned at landing into one-pound food records, preserving the caught weight. These use the existing frying, smoking, cache and sale paths. This is a practical abstraction; there is no separate fish-butchering station. Existing small-fish portion rules remain unchanged.

Regression amendment: `milestone_10.gd`'s “later milestone display refuses sale” assertion will use an unknown item (`sluice`) instead of the newly released spear. `milestone_10_models.gd`'s sale catalogue assertion gains the spear. No pricing, stock, scarcity, or balance thresholds change.

Acceptance evidence and remaining limitations are recorded in PHASE2_CLOSEOUT.md after running the implementation.

Wildlife regression amendment: the bear proximity test now asserts ALERT before explicitly driving it away, then retains the existing flee/contact checks. Unlike deer, the bear must hold the riffle until shouted away. Salmon occupy a shallower strip of the riffle (2.15 m from shore) and tolerate a quiet approach to 1.8 m, making the purchased spear physically usable; other species keep their previous spacing and flight distances.

Closeout refinement: salmon and game-meat portions can be smoked in a batch of up to 20 lb with max(0.1 lb, 0.02 × food weight) salt and four lit hours. The rack record now resides in GameState inventory so camp raids include exposed smoking food.
