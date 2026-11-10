# Ideas progress (branch ideas/look)

The look tab's ideas from the notebook page WackyBars, "Ideas you picked (Nov 10 night, nine)", in the order given: 2, 9, 8, 3, 4.
One line per idea: what it is, its commit, how to try it in game, what runs and when, what the fake game can't show.

- **2 Gradient cooldown pie**: done, commit 112a739. Try it: `/wbars`, Look on Purple to pink, cast something with a cooldown: the pie over the icon is a dark slice of the bar's colour (purple on the left of a bar, pink on the right) instead of black, and the seconds (if the game's "Show numbers for cooldowns" is on) count down in that colour; Look back on Default, the game's dark pie and white seconds are back. Runs: nothing on its own; the colour is written at each look update (a look click, a layout, the button library's own update of a button). Not proven in the fake game: that the game keeps the seconds' colour while it counts (the fake has no countdown), and how the 40% dimmed pie looks over real icons (if it reads too dark or too bright, it is one number, PIE_DIM).
