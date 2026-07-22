---
name: rimvale-touch-ui
description: Convert Rimvale's programmatic Godot Control UI to touch-first mobile layouts — tap targets, long-press replacing hover, card drag-and-drop, safe areas, orientation and scaling. Use when adapting the TCG (or any Rimvale screen) for phones/tablets, or when the user reports mobile UI problems like tiny buttons or missing tooltips.
---

# Rimvale — touch UI conversion

All Rimvale UI is **built in code** (no `.tscn` layouts beyond empty scene
roots), so every change here is a GDScript edit. The TCG's UI lives in
`scenes/cards/card_mode.gd` (~1500 lines) and `scenes/cards/card_setup.gd`.

Shared helpers: `RimvaleUtils.button/label/card/spacer`, palette in
`RimvaleColors`. Reuse them — don't hand-roll new styles.

## The five things that actually break on touch

### 1. Hover previews do not exist on touch — this is the big one
`card_mode.gd` uses `mouse_entered` / `mouse_exited` to show the full card
detail panel (`_show_hover_preview` / `_hide_hover_preview`), plus several
`tooltip_text` strings. **Neither fires from a finger.** On mobile the player
loses the ability to read a card before committing to it.

Replacement pattern — long-press to preview:
```gdscript
const LONG_PRESS := 0.4

func _connect_card_input(panel: Control, card: Dictionary, on_tap: Callable) -> void:
    var held := {"t": 0.0, "fired": false}
    panel.gui_input.connect(func(e: InputEvent) -> void:
        var t := e as InputEventScreenTouch
        if t != null:
            if t.pressed:
                held["t"] = Time.get_ticks_msec()
                held["fired"] = false
            else:
                if not held["fired"]:
                    on_tap.call()          # short tap = select
                _hide_hover_preview()      # release always dismisses
    )
    # drive the long-press from _process or a Timer:
    #   if pressed and now - held.t > LONG_PRESS*1000 and not held.fired:
    #       held.fired = true; _show_hover_preview(card)
```
Keep the mouse path working too — desktop Rimvale still ships. Guard with
`DisplayServer.is_touchscreen_available()` rather than deleting handlers.

Every `tooltip_text` in the TCG (the ✕ quit button, Stow, Banish, the
difficulty toggles) needs the same treatment or the information is simply
unreachable on a phone.

### 2. Tap targets are too small
Current sizes in `card_mode.gd`:
```gdscript
const SLOT_SIZE := Vector2(150, 148)          # 2-player board card
const SLOT_SIZE_COMPACT := Vector2(112, 112)  # 3–4 player board card
const HAND_SIZE := Vector2(140, 150)
```
Plus in-card buttons at **22 px tall** (the 🗑 Discard / ✦ Banish row) and
30–34 px popup buttons.

Rule of thumb: ~**48 dp** minimum. With the 1920×1080 viewport and
`canvas_items` stretch on a 1080p phone the mapping is roughly 1:1, so 22 px
buttons are less than half the minimum and will be mis-tapped constantly.

Fixes, in order of preference:
1. Raise the in-card action buttons to ≥ 44 px and give them horizontal
   breathing room.
2. Move per-card actions (Discard / Banish) **out of the card** into a bottom
   action bar that appears when a card is selected — more room, no crowding.
3. Keep `SLOT_SIZE_COMPACT` for 3–4 player matches but bump the *touchable*
   area with an invisible padded `Control` behind each card.

### 3. Drag-and-drop is the natural card gesture
Tap-to-select then tap-to-target (the current model) works and should stay as
the fallback, but dragging a card from hand onto a slot is what players expect.
Godot's built-in `_get_drag_data` / `_can_drop_data` / `_drop_data` on the
hand panels maps cleanly onto the existing validation:
- `_can_drop_data` → reuse `CardSystem.can_equip()` for gear/feats/spells and
  the empty-slot check for characters. The highlight logic in `_slot_highlight`
  already knows every legal target — call it rather than duplicating rules.
- `_drop_data` → call the same `CardSystem.play_character/equip_card` the tap
  path calls, then `_refresh_board()`.

### 4. Safe areas and notches
```gdscript
var safe := DisplayServer.get_display_safe_area()
var win  := DisplayServer.window_get_size()
# inset the root MarginContainer in _build_layout() by the difference
```
The TCG's quit ✕ sits at `PRESET_TOP_RIGHT` with a 10 px offset — that lands
under a notch or camera cutout on many phones. The opponent strips at the top
have the same exposure.

### 5. Aspect ratio, not just resolution
The board stacks: opponent strips → opponent slots → center bar (log + End
Turn) → your slots → your strip → hand row. On a 20:9 phone in landscape
there's *less vertical* room than the 1920×1080 design assumes, and the
match log (110 px) plus hand row (`HAND_SIZE.y + 30`) squeeze the board.

Mobile layout adjustments that preserve the design:
- Collapse the match log to 2–3 lines with a tap-to-expand overlay.
- Make the hand row a horizontally-scrolling strip of **peeking** cards
  (show ~70% of each) instead of full-width panels.
- In 3–4 player matches, collapse non-active opponents to strip-only rows and
  let a tap expand that opponent's board.

## Orientation

Landscape is correct for the current design (`handheld/orientation="landscape"`).
Portrait would require a genuine redesign — a vertical board with your slots
above the hand and opponents behind a tab. Don't half-do it; if the user wants
portrait, treat it as its own layout function branching in `_build_layout()`.

## Testing the conversion

Run these on-device, not in the editor:
- Every action reachable: play, equip, attack, cast, sacrifice, stow, banish,
  discard, draw, end turn, quit.
- Long-press preview works on both board cards and hand cards.
- Nothing important sits under a notch, gesture bar, or rounded corner.
- Rotating the device mid-match doesn't corrupt the board (`_refresh_board()`
  rebuilds from `CardSystem` state, so it should be safe — verify).
- The hotseat handoff overlay still fully covers the screen (it must, or
  players see each other's hands).
