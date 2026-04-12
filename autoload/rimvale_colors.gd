## rimvale_colors.gd
## Global color palette matching the Rimvale Mobile design system.
## Access via: RimvaleColors.BG_DARK  etc.

extends Node

# ── Backgrounds ──────────────────────────────────────────────────────────────
const BG_DARK       := Color(0.102, 0.039, 0.180, 1.0)  # #1A0A2E  deep purple
const BG_CARD       := Color(0.102, 0.137, 0.494, 1.0)  # #1A237E  dark navy
const BG_CARD_DARK  := Color(0.063, 0.063, 0.137, 1.0)  # #101123  darker card
const BG_DIALOG     := Color(0.102, 0.039, 0.180, 0.96) # #1A0A2E  dialog overlay
const BG_FUSION     := Color(0.176, 0.106, 0.137, 1.0)  # #2D1B23  fusion mode
const BG_NAV        := Color(0.071, 0.035, 0.133, 1.0)  # #120922  nav bar

# ── Text ─────────────────────────────────────────────────────────────────────
const TEXT_WHITE    := Color(1.000, 1.000, 1.000, 1.0)
const TEXT_LIGHT    := Color(0.870, 0.870, 0.870, 1.0)
const TEXT_GRAY     := Color(0.580, 0.580, 0.580, 1.0)
const TEXT_DIM      := Color(0.380, 0.380, 0.380, 1.0)

# ── Accent ───────────────────────────────────────────────────────────────────
const ACCENT        := Color(0.816, 0.576, 0.847, 1.0)  # #CE93D8  magenta
const GOLD          := Color(1.000, 0.843, 0.000, 1.0)  # #FFD700  leader gold
const CYAN          := Color(0.000, 0.898, 1.000, 1.0)  # #00E5FF  team cyan
const ORANGE        := Color(0.902, 0.318, 0.000, 1.0)  # #E65100  summon/action
const RF_PURPLE     := Color(0.290, 0.102, 0.420, 1.0)  # #4A1A6B  remnant frags
const PRIMARY       := Color(0.816, 0.737, 1.000, 1.0)  # #D0BCFF  primary purple

# ── Status bars ──────────────────────────────────────────────────────────────
const HP_GREEN      := Color(0.298, 0.686, 0.314, 1.0)  # #4CAF50
const AP_BLUE       := Color(0.129, 0.588, 0.953, 1.0)  # #2196F3
const SP_PURPLE     := Color(0.612, 0.153, 0.690, 1.0)  # #9C27B0

# ── Semantic ─────────────────────────────────────────────────────────────────
const SUCCESS       := Color(0.298, 0.686, 0.314, 1.0)  # green
const DANGER        := Color(0.902, 0.212, 0.212, 1.0)  # red
const WARNING       := Color(0.945, 0.627, 0.000, 1.0)  # amber
const DISABLED      := Color(0.380, 0.380, 0.380, 1.0)  # gray

# ── Separator ────────────────────────────────────────────────────────────────
const DIVIDER       := Color(1.0, 1.0, 1.0, 0.10)
