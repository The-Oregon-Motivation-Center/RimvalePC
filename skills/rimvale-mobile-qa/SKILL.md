---
name: rimvale-mobile-qa
description: Test the Rimvale TCG on Android — device matrix, touch input edge cases, lifecycle (rotate/background/interrupt), and a rules-level regression checklist covering the card engine. Use when validating a mobile build, chasing a device-specific bug, or before any Play submission.
---

# Rimvale TCG — mobile QA

Two layers to test: **platform behavior** (touch, lifecycle, screen shapes)
and **game rules** (the card engine, which is shared with desktop and should
behave identically). Rules bugs found on mobile are usually engine bugs —
reproduce on desktop before blaming Android.

## Device matrix

Minimum meaningful coverage:

| Class | Why |
|---|---|
| Mid-range phone, 1080×2400, ~6.1" | The realistic target; catches tap-target and layout squeeze |
| Tall phone with notch/cutout, 20:9+ | Safe-area failures |
| Budget phone, 720p, 3–4 GB RAM | Performance floor, texture memory |
| 10" tablet | Layout stretch, 4-player board legibility |
| Emulator, API 34 | Fast smoke test only — never the sole verification |

## Touch input

The desktop UI leans on mouse-only affordances; these are the specific
regressions to hunt (see `rimvale-touch-ui` for fixes):

- [ ] **Long-press shows the card detail preview** — on board cards *and*
      hand cards. Hover (`mouse_entered`) never fires on touch.
- [ ] Every `tooltip_text` has a reachable touch equivalent (quit ✕, Stow,
      Banish, difficulty toggles, draw button).
- [ ] In-card buttons (🗑 Discard / ✦ Banish, 22 px tall on desktop) are
      comfortably tappable — no mis-taps selecting the card instead.
- [ ] Tapping a card then tapping a target still works even if drag-and-drop
      was added; both paths must reach the same `CardSystem` call.
- [ ] Right-click-to-cancel has a touch replacement (the ✕ Cancel button
      covers this — verify it appears in every targeting mode).
- [ ] Scrolling the hand row doesn't accidentally select/discard a card.
- [ ] Two-finger taps and edge swipes don't fire game actions.

## Lifecycle

- [ ] Rotate mid-match → board rebuilds correctly, no lost selection state
- [ ] Background the app mid-AI-turn → returns without the AI stalling
      (the AI uses `await create_timer`; confirm it resumes)
- [ ] Phone call / notification interrupt during the hotseat handoff overlay →
      overlay still fully opaque on return (**hands must never leak**)
- [ ] Android back gesture → routes to the quit-confirm dialog, never an
      instant app kill mid-match
- [ ] Low-memory kill and relaunch → no corrupt state (the TCG holds match
      state in the `CardSystem` autoload only; a kill loses the match, which
      is acceptable if it doesn't crash on relaunch)

## Rules regression checklist

Run once per build on-device. These exercise the systems most likely to
silently break, and every one is observable in the match log.

**Economy**
- [ ] Opening hand is 9; the turn-1 free draw brings it to 10
- [ ] Over 10 cards forces discards before any other action
- [ ] Paid draw costs 1 energy; energy ramps 1→5
- [ ] Face attacks cost 1 energy and are blocked at 0

**Combat math** (the log prints full breakdowns — read them)
- [ ] Attack shows `🎲 raw+mod = total vs AC n`, and the mod matches the
      number on the Attack button
- [ ] Crits double dice; Precise Tactician's crit range widens per tier
- [ ] Player AC reads 10 + 2 per character in play, and updates live
- [ ] Damage reduction never exceeds the cap of 6
- [ ] Bleeding ticks 1d4 each turn and is announced

**Cards and progression**
- [ ] A card played this round cannot attack, but can cast
- [ ] Action costs escalate 1, 2, 3… and reset each round
- [ ] Spent cards go grey; ⚡ Refresh AP restores them for 1 energy
- [ ] Level-ups bank an attribute point (manual is the default); spending it
      updates HP/AP/SP/AC immediately
- [ ] Stats cap at 10, then convert to +10 HP
- [ ] Sacrifice grants +1 level, or absorbs HP at level 20
- [ ] Duplicate feat steps the **real** tier ladder (Iron Vitality 1→3→5, not
      1→2) and refuses past its cap
- [ ] Duplicate weapon forges +1/+2/+3 and stops there
- [ ] Whetstone/Aegis affect **only** the chosen card — not every card of that
      lineage (this was a real bug; regression-test it)

**Modes**
- [ ] Gauntlet: defeating a challenger does NOT end the run; a replacement
      arrives after 2 rounds; up to 10 graveyard cards shuffle into the deck
- [ ] Gauntlet: End Gauntlet banks the score with a distinct modal
- [ ] 4-player: turn order skips eliminated seats; last standing wins
- [ ] Hotseat: the pass-device overlay is fully opaque

## Reporting a bug

Include: device + Android version, build (debug/release), the **match log
lines** around the failure (they contain the dice math), and whether it
reproduces on desktop. A rules bug that reproduces on desktop belongs in
`autoload/card_system.gd`, not in the Android layer.
