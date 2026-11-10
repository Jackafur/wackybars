# Ideas progress (branch ideas/features)

One line per idea: what it is, the commit, how you try it in game, what runs and when, what the fake game cannot show.

- **1 Ding wave**: done, commit `37009a4` (`WackyBars/Ding.lua`). Try: `/wbars ding` (or level up): a purple to pink glow runs once over every bar, left to right, about 2 seconds, also while QuietHUD has the bars faded. Runs: nothing until a level up (one event); then the game's animations for 2 seconds, no OnUpdate, no timer. Not proven: how strong it looks on screen (half strength, the game's spell highlight art), that it sits under the key text, the real left-to-right timing across your three bars.
