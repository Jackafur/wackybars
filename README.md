# WackyBars

Your keys as action bars, placed like the keys (redesigned Nov 10). Shown by default:

- **Keyboard:** the rows `1 2 3 4 5 6` / `Q W E R T Y` / `Caps A S D F G H` / `Z X C V` + Shift wheel up, Shift wheel
  down (`sWU`, `sWD`: the plain wheel is the camera, so the two after V are your Shift + wheel Spam). Straight rows, Caps
  two buttons wide left of A; a box in the options staggers the rows like the keyboard.
- **Mouse (Naga Pro):** the side grid 3 by 4 (F1, F2, F3, Page Down, F5 to F10, `-`, `=` in the `wow` profile); the
  wheel click above side 2, full size; left of the grid a column with E1 on top (Numpad *) and E2 (Numpad /), 75% size.
  Shift / Ctrl / Alt + wheel click and + E1, E2 are on the copies.
- **Hypershift:** the same shape: the grid on Numpad 1 to 9, 0, -, + (your items, the slots of the game's Action Bar 8)
  and E1, E2 and the wheel click as blank buttons (what Hypershift + those send isn't written down: hover one in Edit
  keys and press it).

**Off by default, a box each:** Shift, Ctrl and Alt copies of the keyboard and the mouse bars (the plan is married
macros, `[mod:shift]` on the plain key, so these stay empty). On the Shift and Ctrl keyboard copies the two spots after V
are blank buttons (no key, not B and N; Shift + wheel is on the plain bar). Switched on, a copy first shows in the middle
of the screen (keyboard ones left, mouse ones right, each a little down and right of the one before), so none is pushed
onto another; where two overlap, the later one's box is on top.

**The game's eight action bars are hidden** while any WackyBars bar shows (tucked under a hidden frame, not switched
off, so their keys and stealth / vehicle paging still work). The stance and possess bars stay the game's. All
WackyBars bars off, or WackyBars off in the AddOns list: the game's bars are back.

**Look** (`/wbars`, one button that opens a short list): Default copies your Action Bar 1 (BetterBlizzFrames' Dark Mode
tint with it). The colour looks put one gradient across each bar: Purple to pink (`#BD93F9` to `#FF79C6`, the desktop's
colours), Dracula (`#8BE9FD` to `#BD93F9`), Nord (`#88C0D0` to `#5E81AC`), Gruvbox (`#FE8019` to `#FABD2F`) or Catppuccin
(`#CBA6F7` to `#FAB387`). Each button takes its slice: its frame, its cooldown pie (dimmed, the seconds in the slice's
colour) and a proc's glow; the pet buttons in it too, the movement arrows, and the minimap's ring (the game's,
BetterBlizzFrames' classic border and day / night ring). Back to Default puts the game's dark pie, the yellow glow and
BetterBlizzFrames' own colours back at once, no reload.

**Arrows** (`/wbars`, one button): how strong the movement arrows are, 20, 30 (default), 50, 70 or 100%. QuietHUD's fade
multiplies on top.

**Bar art** (`/wbars`, a box, off by default): the faint wing in empty buttons, as on Action Bar 1 with its bar art. Off,
an empty button is a plain dark slot, as on the game's other bars.

**Pet keys:** a key bound to a pet bar key in Key Bindings (Alt + F1 to F10 on the Alt mouse bar, say) shows the game's own
pet button for it: the right abilities for whatever pet is out, autocast and cooldowns as on the game's bar, shown only
with a pet. The other buttons of that bar stay action buttons. While any pet button sits on a WackyBars bar the game's pet
bar is hidden; QuietHUD fades that whole bar, its other buttons too, with its Pet bar row (Elements page).

Keys bound to moving (ESDF, WASD, whatever Key Bindings say) show a faint arrow instead of a button. The buttons are
Bartender4's: LibActionButton-1.0 (with LibStub, CallbackHandler-1.0, LibButtonGlow-1.0, copied from Bartender 4.18.4
into `WackyBars/libs/`; BSD-style licences, headers kept). Their secure state lives in attributes, so the game never
blames WackyBars for a click, a hover in a fight or a stance change (the game's own ActionBarButtonTemplate, used until
Nov 10, did: audit of Nov 10). Action Bar 1's mirrors hold every page (state n = page n) and the pager uses Bartender's
paging order (vehicle / override / possess / temporary shapeshift, then a picked page, then stance only on page 1). Keys
WackyBars binds press buttons Bartender's way ("Keybind"), so key down casting works. Dragging follows the game's Lock
Action Bars. Each button is laid out like Action Bar 1's buttons with the bar art on (ActionButtonTemplate: the 46 x 45
frame at the top left with no drop shadow, the icon mask at its own size, the highlight on the frame), scaled for a wide
key or a smaller spot; only
Action Bar 1's colour is copied on (BetterBlizzFrames dark mode, or the game's own look without it).

**QuietHUD mirrors per bar.** Each bar holds eight small frames, `WackyBarsHold<bar><1 to 8>`, one per game bar, and the
whole bar sits in the one of the game bar most of its buttons show slots of (keyboard: Bar 1, thumbs: Bar 4,
Hypershift: Bar 8; the Alt keyboard always Bar 1, the Alt mouse with the plain mouse bar, his pick). Per button it left
stragglers (Shift + wheel click stayed shown on a mouse over bar), so one bar, one row. QuietHUD lists those holders with
their game bar, so the bar follows that bar's row on its Action bars page, where the rows carry WackyBars' names: Fade,
Mouse over only, Low health, Low mana, Click through, Show with Alt, Hide hotkeys, Hide names (Shorten hotkey text stays
WackyBars' own labels). Needs QuietHUD newer than 1.6.1 for this. The holders have no size; their `qhudButtons` count for mouse over. The "WackyBars" frame itself
is not faded. Pixel shift moves the bars. WackyBars has no fade settings of its own. The move boxes are named
`WackyBarsMove<bar>`.

- **Port, nothing moves:** each button shows the slot its key fires today (read from your saved bindings). Saved
  bindings are never written. A key you didn't touch keeps going through the game's own button.
- **Free keys** (nothing bound) get a spare slot: 13 to 24, then 73 to 84 (not Rogues: Stealth), then 85 to 120
  (Druid, Warrior, Priest: 13 to 24 only), never one that holds something. A filled one stays that button's; empty ones
  are handed out again each time, plain bars first, then the Shift, Ctrl and Alt copies, and a bar switched off takes
  none. A Naowh import empties them unless its code lists them. The Caps button is the `\` key: on the Linux PC Caps
  types `\` (a custom KDE keyboard option), so the game never sees CAPSLOCK. Whatever you bind to `\` that isn't an
  action bar button (LockMenu) is left alone.
- **Options:** `/wbars` (or a key in Key Bindings, WackyBars; also Esc, Options, AddOns): a box per bar (keyboard and
  mouse side by side, a row each for Plain, Shift, Ctrl, Alt; Hypershift under them), staggered rows, show the modifier
  in labels (`sQ`, `cQ`, `aQ`, `h1`; off by default, your pick), snap when moving bars, Edge buttons (E1, E2) and Wheel
  click button (on; off takes them out of every bar, for a mouse without them, and the bar closes up), Move bars,
  Edit keys, Reset places (places and sizes).
- **Size, each bar its own:** in Move bars, click a bar: a slider (50% to 200%, steps of 5, with - and +) sizes that bar,
  its top left corner staying put, like Edit Mode's Icon Size. `/wbars scale <n>` sets every bar at once, `auto` puts
  them all back to 100%. The one size of before became each bar's size on the first load.
- **Move bars:** each bar shows a blue box with its name; drag it (the one you pick turns gold, arrow keys nudge it 1
  pixel, Shift 10). It snaps by the game's Edit Mode rules (copied from `EditModeMagnetismManager`): within 8 pixels,
  to the screen (sides, middle, a side to the middle) and a grid line (Edit Mode's Grid Spacing, drawn faint) both ways;
  to another bar only edge to edge and only one it overlaps (beside it, or above or below), then only the nearer way; a
  corner within 8 x 1.4 beats everything. Lines show where it will land while you drag. Not copied: a game bar snapped
  to another moves with it later, WackyBars bars keep their own place. The boxes also come up in the game's own Edit
  Mode and snap there when its Snap is on and its grid shows. Esc finishes. Places are per character.
- **Edit keys:** hover a button, press the key you want (modifiers, middle and side mouse buttons, wheel). Esc on a
  button clears its key, right-click hides a button (faint while editing, right-click again brings it back),
  Esc elsewhere finishes. All of it is override bindings, gone when WackyBars is off.
- Slash: `/wbars move`, `edit`, `scale <n|auto>` (every bar), `stagger`, `reset`, `status`.
- **First load after Nov 10** (and a new character): plain bars and Hypershift on, the copies off; the old mouse over,
  hide in fight, Lite and game bars settings, and spare slots of buttons that no longer exist, are dropped. Once only.

Tests: `luajit tests/wackybars_test.lua`, `tests/first_load_test.lua`, `tests/quiethud_mirror_it.lua`,
`tests/quiethud_shifts_it.lua` (need `wow-addon-harness` and `wow-quiethud` beside this folder). Install: copy `WackyBars/` into `_forever_/Interface/AddOns`; a new addon or a
Bindings.xml change needs a full game restart, a Lua change a `/reload`. Tests load `tests/fake_lab.lua`, a stand-in for the library.
